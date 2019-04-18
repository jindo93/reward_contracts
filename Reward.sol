pragma solidity ^0.5.2;

import "./SafeMath.sol";

contract AddCandidateThenReward {
    using SafeMath for uint;
    
    uint private total_rewarded;
    mapping(address => uint) private reward_balance;
    
    address payable public this;
    address public _owner;
    address public _rewarder;
    address public _manager;

    address[] private rewardee_list;
    address[] private rewarded_list;

    event RewardeeAdded(address _rewardee, uint _rewardeeCount);
    event Rewarded(address _rewardee, uint _amount);
    
    modifier onlyOwner { 
        require(msg.sender == _owner);
        _;
    }
    modifier onlyManager {
        require(msg.sender == _manager);
        _;
    }
    modifier onlyRewarder {
        require(msg.sender == _rewarder);
        _;
    }
    
    constructor() public payable {
        require(msg.value > 0);
        // owner = rewarder, manager for testing convenience
        _owner = msg.sender;
        _rewarder = msg.sender;
        _manager = msg.sender;
        address(this).transfer(msg.value);        
        reward_balance[address(this)] = msg.value;

    }
    

    function RewardeeList() public view returns(address[] memory) {
        return rewardee_list;
    }
    
    function RewardeeCount() public view returns(uint) {
        return rewardee_list.length;
    }
    
    function RewardedList() public view returns(address[] memory) {
        return rewarded_list;
    }
    
    function RewardedCount() public view returns(uint) {
        return rewarded_list.length;
    }

    function balanceOf(address _addr) public view returns(uint) {
        require(_addr != address(0));
        return reward_balance[_addr];
    }
    
    function addRewardee(address _addr) public onlyOwner returns(uint) {
        require(_addr != address(0));
        rewardee_list.push(_addr);
        reward_balance[_addr] = 0;
        emit RewardeeAdded(_addr, rewardee_list.length);
        return rewardee_list.length;
    }
    
    function contains(address[] memory _list, address _addr) private pure returns(bool) {
        uint j = _list.length;
        for(uint i=0; i<j;  i++) {
            if(_list[i]==_addr) { 
                return true; 
            }
        }
        return false;
    }

    function rewardCandidate(address payable rewardee, uint amount) public onlyRewarder returns(uint) {
        require(amount > 0);
        require(address(this).balance >= amount);
        require(contains(rewardee_list, rewardee) == true); //checks if the given address is contained in the contract
        
        rewardee.transfer(amount);
        reward_balance[address(this)] = reward_balance[address(this)].sub(amount);
        reward_balance[rewardee] = reward_balance[rewardee].add(amount);
        total_rewarded = total_rewarded.add(amount);
        rewarded_list.push(rewardee);
        emit Rewarded(rewardee, amount);
        return total_rewarded;
    }

}