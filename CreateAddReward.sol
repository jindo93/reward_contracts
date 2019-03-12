pragma solidity ^0.4.24;

import "./SafeMath.sol";

contract AddAndReward {
    using SafeMath for uint;
    

    address public owner;
    address public newOwner;
    address public manager;
    address public newManager;
    
    uint progCount;
    uint mgmtBalance;
    //alias for progId -> need a database to keep tract and update progId
    //                  and use it on the front-end to restrict access
    //custum objects
    struct Rewardee {
        address addr;
        uint rewarded_amount;
        bool registered;
        bool rewarded;
    }
    mapping(address => uint) mgmt_deposit;
    
    struct Info {
        uint rwdId;
        bool registered;
    }
    
    struct Program {
        string progName; // ex. program name 'Cryptography'
        // program authorities
        address progOwner; // owner of this contract
        address progNewOwner;
        address progManager; // who adds rewardees into the contract
        address progNewManager;
        address progRewarder; // who pays out rewards to rewardees
        address progNewRewarder;
        
        uint start_time; // keeps tract of when the program started
        uint days_left; // keeps tract of when the program ended;
        // if the program ends with balances left, the balances are either sent back to the
        // contract creator or payed out to rewardees proportionally
        uint progBalance; // reward balance deposited by the owner
        uint rewardedCount; // number of times rewarded to rewardees
        uint rewardeeCount;

        mapping(address => Info) rwd_info; // rewardee info
        mapping(uint => Rewardee) rewardees; // rewardees in this program
        mapping(address => uint) program_deposit; // who deposit into this program
    }

    mapping(uint => Program) programs;

    event ProgramOwnerChanged(uint _progId, address _from, address _to);
    event ProgramManagerChanged(uint _progId, address _from, address _to);
    event ProgramRewarderChanged(uint _progId, address _from, address _to);
    event ProgramCreated(uint _progId, string _progName, uint _end_time); 
    // Not sure whether end_time should be bytes or uint
    event RewardeeRegistered(uint _progId, uint _rwdId, uint _rewardeeCount);
    event RewardeeRewarded(uint _progId, uint _rwdId, address _rewardee, uint _amount);
    event DepositerRegistered(uint _progId, address _depositer);
    event DepositToProgram(uint _progId, address _from, uint _amount);
    event DepositToContract(address _from, uint _amount);
    event LockedProgram(uint _progId, uint _locked_time);
    event TransferredOwnership(address _from, address _to);
    event TransferredManager(address _from, address _to);

    modifier onlyOwner { 
        require(msg.sender == owner);
        _;
    }
    modifier onlyManager {
        require(msg.sender == manager);
        _;
    }

    
    ///////////STATE CHANGING FUNCTIONS//////////////
    
    constructor() public payable {
        progCount = 0;
        mgmtBalance = msg.value;
        mgmt_deposit[msg.sender] = msg.value;
        owner = msg.sender;
        manager = msg.sender;
        address(this).transfer(msg.value);
    }
    
    function () public payable {
        require(msg.value > 0);
        mgmt_deposit[msg.sender] = msg.value;
        address(this).transfer(msg.value);
        emit DepositToContract(msg.sender, msg.value);
    }

    
    function createProgram(string _name, uint _days_left) public {
        uint i = progCount;
        programs[i].progName = _name;
        programs[i].progOwner = msg.sender;
        programs[i].progManager = msg.sender;
        programs[i].progRewarder = msg.sender;
        programs[i].progBalance = 0;
        programs[i].rewardedCount = 0;
        programs[i].rewardeeCount = 0;
        programs[i].start_time = now;
        programs[i].days_left = now + _days_left * 1 days;
        
        emit ProgramCreated(i, _name, _days_left);
        progCount = progCount.add(1);
    }
    function transferOwnership(address _newOwner) public onlyOwner {
        newOwner = _newOwner;
    }
    function acceptOwnership() public {
        require(msg.sender == newOwner);
        emit TransferredOwnership(owner, newOwner);
        owner = newOwner;
        newOwner = address(0);
    }
    function transferManager(address _newManager) public onlyManager {
        newManager = _newManager;
    }
    function acceptManager() public {
        require(msg.sender == newManager);
        emit TransferredManager(manager, newManager);
        manager = newManager;
        newManager = address(0);
    }
    function transferProgramManager(uint _progId, address _newManager) public {
        require(_progId <= progCount);
        uint i = _progId;
        require(msg.sender == programs[i].progManager);
        programs[i].progNewManager = _newManager;
    }
    function acceptProgramManager(uint _progId) public {
        require(msg.sender == programs[_progId].progNewManager);
        emit ProgramManagerChanged(_progId, programs[_progId].progManager, programs[_progId].progNewManager);
        programs[_progId].progManager = programs[_progId].progNewManager;
        programs[_progId].progNewManager = address(0);
    }
    function transferProgramRewarder(uint _progId, address _newRewarder) public {
        require(_progId <= progCount);
        uint i = _progId;
        require(msg.sender == programs[i].progRewarder);
        programs[i].progNewRewarder = _newRewarder;
    }
    function acceptProgramRewarder(uint _progId) public {
        require(msg.sender == programs[_progId].progNewRewarder);
        emit ProgramRewarderChanged(_progId, programs[_progId].progRewarder, programs[_progId].progNewRewarder);
        programs[_progId].progRewarder = programs[_progId].progNewRewarder;
        programs[_progId].progNewRewarder = address(0);
    }
    function transferProgramOwner(uint _progId, address _newOwner) public {
        require(msg.sender == programs[_progId].progOwner);
        require(_progId <= progCount);
        uint i = _progId;
        require(msg.sender == programs[i].progOwner);
        programs[i].progNewOwner = _newOwner;
    }
    function acceptProgramOwner(uint _progId) public {
        require(msg.sender == programs[_progId].progNewOwner);
        emit ProgramOwnerChanged(_progId, programs[_progId].progOwner, programs[_progId].progNewOwner);
        programs[_progId].progOwner = programs[_progId].progNewOwner;
        programs[_progId].progNewOwner = address(0);
    }
    
    function depositToProgram(uint _progId) public payable returns(bool) {
        uint i = _progId;
        require(msg.value > 0);
        require(i >= progCount);

        address(this).transfer(msg.value);
        programs[i].program_deposit[msg.sender] = programs[i].program_deposit[msg.sender].add(msg.value);
        programs[_progId].progBalance = programs[_progId].progBalance.add(msg.value);
        return true;
    }
    
    function addRewardee(uint _progId, address _addr) public returns(bool) {
        uint i = _progId;
        uint rwd_info;
        uint j = programs[i].rewardeeCount;
        programs[i].rwd_info[_addr].rwdId = j;
        uint k = programs[i].rwd_info[_addr].rwdId;
        require(msg.sender == programs[i].progManager);
        require(!programs[i].rwd_info[_addr].registered);
        require(_addr != address(0));
        programs[i].rwd_info[_addr].registered = true;
        programs[i].rewardees[k].rewarded_amount = 0;
        programs[i].rewardees[k].rewarded = false;
        programs[i].rwd_info[_addr].rwdId = programs[i].rwd_info[_addr].rwdId.add(1);

        emit RewardeeRegistered(_progId, k, programs[_progId].rewardeeCount);
        return true;
    }

    function rewardCandidate(uint _progId, address _rewardee, uint _amount) public returns(bool) {
        uint i = _progId;
        uint j = programs[i].rwd_info[_rewardee].rwdId;
        require(_amount > 0);
        require(i <= progCount);
        require(programs[i].rwd_info[_rewardee].registered);
        require(msg.sender == programs[i].progRewarder);
        require(programs[i].progBalance >= _amount);
        require(address(this).balance >= _amount);

        programs[i].rewardees[j].addr.transfer(_amount);
        programs[i].rewardees[j].rewarded_amount = programs[i].rewardees[j].rewarded_amount.add(_amount);
        programs[i].rewardees[j].rewarded = true;
        emit RewardeeRewarded(i, j, _rewardee, _amount);
        return true;
    }


    ////////////////PROGRAM VIEWER FUNCTIONS////////////////
    function programOwner(uint _progId) public view returns(address) {
        uint i = _progId;
        return programs[i].progManager;
    }
    function programManager(uint _progId) public view returns(address) {
        uint i = _progId;
        return programs[i].progManager;
    }
    function programRewarder(uint _progId) public view returns(address) {
        uint i = _progId;
        return programs[i].progRewarder;
    }
    function programBalance(uint _progId) public view returns(uint) {
        uint i = _progId;
        return programs[i].progBalance;
    }
    function programStartTime(uint _progId) public view returns(uint) {
        uint i = _progId;
        return programs[i].start_time;
    }
    function programEndTime(uint _progId) public view returns(uint) {
        uint i = _progId;
        return programs[i].days_left;
    }
    function programRewardeeCount(uint _progId) public view returns(uint) {
        uint i = _progId;
        return programs[i].rewardeeCount;
    }
    function programRewardedCount(uint _progId) public view returns(uint) {
        uint i = _progId;
        return programs[i].rewardedCount;
    }
    function rewardedAmount(uint _progId, address _rewardee) public view returns(uint) {
        uint i = _progId;
        uint j = programs[i].rwd_info[_rewardee].rwdId;
        return programs[i].rewardees[j].rewarded_amount;
    }
    
    ////////////////INTERNAL FUNCTIONS//////////////////
    function lockProgram(uint _progId) public {
        uint i = _progId;
        require(msg.sender == programs[i].progOwner);
        programs[i].progManager = address(0);
        emit LockedProgram(i, now);
    }
    
    function reward(uint _progId) private {
        uint i = programs[_progId].rewardeeCount;
        
        
    }
      
    ////////////////COMPUTATIONALLY EXPENSIVE FUNCTIONS//////////////////
    function contains(address[] _list, address _addr) private pure returns(bool) {
        uint j = _list.length;
        for(uint i = 0; i < j;  i++) {
            if(_list[i]==_addr) { 
                return true; 
            }
        }
        return false;
    }

}