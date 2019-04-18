pragma solidity ^0.5.2;

import "./ERC20.sol";
import "./SafeMath.sol";

contract RewardERC20 {
    using SafeMath for uint;

    uint private total_rewarded;
    mapping(address => uint) private reward_balance;
    mapping (address => mapping (address => uint256)) private _allowed;

    address public _owner;
    address public _newOwner;
    address public _rewarder;
    address public _manager;

    address[] private rewardee_list;
    address[] private rewarded_list;

    //ERC20 public tokenAddress;// = 0xb6E321a3FDB50359f7a3a9C93F63428A05ABDcAa;
    mapping(bytes4 => ERC20) private token_address;
    bytes4[] private token_list;

    event DepositToken(uint amount);
    event OwnershipTransferred(address indexed _from, address indexed _to);

    modifier onlyOwner {
        require(msg.sender == _owner);
        _;
    }
    modifier onlyRewarder {
        require(msg.sender == _rewarder);
        _;
    }
    modifier onlyManager {
        require(msg.sender == _manager);
        _;
    }

    constructor() public payable {
        _owner = msg.sender;
        _manager = msg.sender;
        _rewarder = msg.sender;
        total_rewarded = 0;
    }

    function () external payable {
        revert();
    }

    function addToken(bytes4 _symbol, ERC20 tokenAddress) public returns(ERC20) {
        token_address[_symbol] = tokenAddress;
        token_list.push(_symbol);
        return tokenAddress;
    }


    function rewardSingle(address payable rewardee, uint amount) public onlyRewarder returns(bool) {
        require(amount > 0);
        require(address(this).balance >= amount);
        require(contains(rewardee_list, rewardee) == true); //checks if the given address is contained in the contract

        rewardee.transfer(amount);
        reward_balance[rewardee] = reward_balance[rewardee].add(amount);
        total_rewarded = total_rewarded.add(amount);
        rewardee_list.push(rewardee);
        return true;
    }

    function addStudents(address _addr) onlyManager public returns(uint) {
        require(_addr != address(0));
        rewardee_list.push(_addr);
        reward_balance[_addr] = 0;
        return rewardee_list.length;
    }

    function contains(address[] memory _list, address _addr) private pure returns(bool) {
        for(uint i=0; i<_list.length; i++) {
            if(_list[i]==_addr) {
                return true;
            }
        }
        return false;
    }

    function RemainingBalance() public view returns(uint) {
        return address(this).balance;
    }

    function Rewarded_Tokens() public view returns(uint) {
        return total_rewarded;
    }
    
    function TokenAddressOf(bytes4 _symbol) public view returns (ERC20) {
        return token_address[_symbol];
    }


    function BalanceOf(address _addr) public view returns (uint) {
        require(_addr != address(0));
        return reward_balance[_addr];
    }
    
    function TokenList() public view returns(bytes4[] memory) {
        return token_list;
    }

    function StudentList() public view returns(address[] memory) {
        return rewardee_list;
    }

    function RewardedList() public view returns(address[] memory) {
        return rewarded_list;
    }

    function Rewarded_Count() public view returns(uint) {
        return rewardee_list.length;
    }

    function RewardedStudentCount() public view returns(uint) {
        return rewarded_list.length;
    }

    function transferOwnership(address newOwner) public onlyOwner {
        _newOwner = newOwner;
    }

    function acceptOwnership() public {
        require(msg.sender == _newOwner);
        emit OwnershipTransferred(_owner, _newOwner);
        _owner = _newOwner;
        _newOwner = address(0);
    }

}