pragma solidity 0.8.26;

import {Address} from "openzeppelin-contracts/utils/Address.sol";
import {ECDSA} from "openzeppelin-contracts/utils/cryptography/ECDSA.sol";
import {EIP712} from "openzeppelin-contracts/utils/cryptography/EIP712.sol";
import {ERC2771Context} from "openzeppelin-contracts/metatx/ERC2771Context.sol";
import {EnumerableSet} from "openzeppelin-contracts/utils/structs/EnumerableSet.sol";

using EnumerableSet for EnumerableSet.AddressSet;

contract Caller is EIP712("Caller", "1"), ERC2771Context(address(this)) {
    uint256 public constant MAX_NONCE_INCREASE = 10 ** 9;
    string internal constant CALL_SIGNED_TYPE_NAME = "CallSigned(address sender,address target,bytes data,uint256 value,uint256 nonce,uint256 deadline)";
    bytes32 internal immutable callSignedTypeHash = keccak256(bytes(CALL_SIGNED_TYPE_NAME));

    mapping(address => AddressSetClearable) internal _authorized;
    mapping(address => uint256) public nonce;

    struct AddressSetClearable {
        uint256 clears;
        mapping(uint256 => EnumerableSet.AddressSet) addressSets;
    }

    event CalledAs(address indexed sender, address indexed authorized);
    event Authorized(address indexed sender, address indexed authorized);
    event Unauthorized(address indexed sender, address indexed unauthorized);
    event UnauthorizedAll(address indexed sender);
    event CalledSigned(address indexed sender, uint256 nonce);
    event NonceSet(address indexed sender, uint256 newNonce);

    function authorize(address user) public {
        address sender = msg.sender;
        require(_getAuthorizedSet(sender).add(user), "Already authorized");
        emit Authorized(sender, user);
    }

    function unauthorize(address user) public {
        address sender = msg.sender;
        require(_getAuthorizedSet(sender).remove(user), "Not authorized");
        emit Unauthorized(sender, user);
    }

    function unauthorizeAll() public {
        address sender = msg.sender;
        _authorized[sender].clears++;
        emit UnauthorizedAll(sender);
    }

    function isAuthorized(address sender, address user) public view returns (bool) {
        return _getAuthorizedSet(sender).contains(user);
    }

    function allAuthorized(address sender) public view returns (address[] memory) {
        return _getAuthorizedSet(sender).values();
    }

    function callAs(address sender, address target, bytes calldata data) public payable returns (bytes memory) {
        address authorized = msg.sender;
        require(isAuthorized(sender, authorized), "Not authorized");
        emit CalledAs(sender, authorized);
        return _call(sender, target, data, msg.value);
    }

    function callSigned(address sender, address target, bytes calldata data, uint256 deadline, bytes32 r, bytes32 sv) public payable returns (bytes memory) {
        require(block.timestamp <= deadline, "Expired");
        uint256 currNonce = nonce[sender]++;
        emit CalledSigned(sender, currNonce);
        return _call(sender, target, data, msg.value);
    }

    function setNonce(uint256 newNonce) public {
        address sender = msg.sender;
        uint256 currNonce = nonce[sender];
        require(newNonce > currNonce, "Not increased");
        require(newNonce <= currNonce + MAX_NONCE_INCREASE, "Too high");
        nonce[sender] = newNonce;
        emit NonceSet(sender, newNonce);
    }

    function callBatched(Call[] calldata calls) public payable returns (bytes[] memory) {
        bytes[] memory results = new bytes[](calls.length);
        address sender = msg.sender;
        for (uint256 i = 0; i < calls.length; i++) {
            results[i] = _call(sender, calls[i].target, calls[i].data, calls[i].value);
        }
        return results;
    }

    function _getAuthorizedSet(address sender) internal view returns (EnumerableSet.AddressSet storage) {
        return _authorized[sender].addressSets[_authorized[sender].clears];
    }

    function _call(address sender, address target, bytes calldata data, uint256 value) internal returns (bytes memory) {
        return Address.functionCallWithValue(target, bytes.concat(data, bytes20(sender)), value);
    }
}

struct Call {
    address target;
    bytes data;
    uint256 value;
}