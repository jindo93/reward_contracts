pragma solidity ^0.4.24;

import "./SafeMath.sol";

contract Organization {
    using SafeMath for uint;
    

    address public owner;
    address public newOwner;
    address public manager;
    address public newManager;
    
    uint public pCount;
    //alias for progId -> need a database to keep tract and update progId
    //                  and use it on the front-end to restrict access
    //custum objects
    struct Rewardee {
        address addr;
        uint reward;
        bool rewarded;
        uint total_rewarded;
    }
    mapping(address => uint) public sponsor_deposits; // external sponsorship
    mapping(address => mapping(uint => uint)) public program_deposits;
    // deposit not directly to a program
    
    struct Info { // object for cross referennce
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
        uint registeredCount;

        mapping(address => Info) rwd_info; // rewardee info
        mapping(uint => Rewardee) rewardees; // rewardees in this program
    }

    mapping(uint => Program) public programs;


    event TransferredOwnership(address _from, address _to);
    event TransferredManager(address _from, address _to);

    event ProgramCreated(uint _progId, string _progName, uint _end_time, uint _pCount); 
    event LockedProgram(uint _progId, uint _locked_time);
    event RewardeeRegistered(uint _progId, uint _rwdId, uint _rewardeeCount);
    
    event ProgramOwnerChanged(uint _progId, address _from, address _to);
    event ProgramManagerChanged(uint _progId, address _from, address _to);
    event ProgramRewarderChanged(uint _progId, address _from, address _to);
    
    event DepositToProgram(uint _progId, address _from, uint _amount);
    event DepositToContract(address _from, uint _amount);

    event InitiatedReward(uint _pid, uint _rid, uint _amount);
    event WithdrawReward(uint _pid, uint _rid, uint _amount);


    modifier onlyOwner { 
        require(msg.sender == owner);
        _;
    }
    modifier onlyManager {
        require(msg.sender == manager);
        _;
    }
    modifier onlyProgramOwner(uint _pid) {
        require(msg.sender == programs[_pid].progOwner);
        _;
    }
    modifier onlyProgramManager(uint _pid) {
        require(msg.sender == programs[_pid].progOwner);
        _;
    }
    modifier onlyProgramRewarder(uint _pid) {
        require(msg.sender == programs[_pid].progRewarder);
        _;
    }

    
    ///////////STATE CHANGING FUNCTIONS//////////////
    
    constructor() public payable {
        pCount = 0;
        sponsor_deposits[msg.sender] = msg.value;
        owner = msg.sender;
        manager = msg.sender;
        address(this).transfer(msg.value);
    }
    
    function () public payable {
    }

    function createProgram(string _name, uint _days_left) public {
        programs[pCount].progName = _name;
        programs[pCount].progOwner = msg.sender;
        programs[pCount].progManager = msg.sender;
        programs[pCount].progRewarder = msg.sender;
        programs[pCount].progBalance = 0;
        programs[pCount].rewardedCount = 0;
        programs[pCount].registeredCount = 0;
        programs[pCount].start_time = now;
        programs[pCount].days_left = now + _days_left * 1 days;

        emit ProgramCreated(pCount, _name, _days_left, pCount);
        pCount = pCount.add(1);
    }


    function depositToProgram(uint _pid) public payable {
        require(msg.value > 0);
        require(_pid <= pCount);

        program_deposits[msg.sender][_pid] = program_deposits[msg.sender][_pid].add(msg.value);
        programs[_pid].progBalance = programs[_pid].progBalance.add(msg.value);

        address(this).transfer(msg.value);
    }
    
    function addRewardee(uint _pid, address _addr) public onlyProgramManager(_pid) returns(bool) {
        require(_addr != address(0));
        require(!programs[_pid].rwd_info[_addr].registered);
        require(programs[_pid].registeredCount < 100); 
        //ensure there are less than 100 rewardees registered for computational cost
        
        uint k = programs[_pid].registeredCount;
        programs[_pid].rwd_info[_addr].rwdId = k;

        programs[_pid].rwd_info[_addr].registered = true;
        programs[_pid].rewardees[k].reward = 0;
        programs[_pid].rewardees[k].total_rewarded = 0;
        programs[_pid].rewardees[k].rewarded = false;
        programs[_pid].rewardees[k].addr = _addr;
        programs[_pid].registeredCount = programs[_pid].registeredCount.add(1);

        emit RewardeeRegistered(_pid, k, programs[_pid].registeredCount);
        return true;
    }

    function rewardCandidate(uint _pid, uint _rid, uint _amount) public onlyProgramRewarder(_pid) returns(bool){
        require(_amount > 0);
        require(_pid <= pCount);
        require(_rid <= programs[_pid].registeredCount);
        address a = programs[_pid].rewardees[_rid].addr;
        require(programs[_pid].rwd_info[a].registered);
        require(programs[_pid].progBalance >= _amount);
        require(address(this).balance >= _amount);

        programs[_pid].progBalance = programs[_pid].progBalance.sub(_amount);
        programs[_pid].rewardees[_rid].reward = programs[_pid].rewardees[_rid].reward.add(_amount);
        emit InitiatedReward(_pid, _rid, _amount);
        return true;
    }
    
    function withdraw(uint _pid) payable external {
        require(programs[_pid].rwd_info[msg.sender].registered);
        uint id = programs[_pid].rwd_info[msg.sender].rwdId;
        uint pay = programs[_pid].rewardees[id].reward;
        programs[_pid].rewardees[id].reward = 0;
        programs[_pid].rewardees[id].total_rewarded = programs[_pid].rewardees[id].total_rewarded.add(pay);
        msg.sender.transfer(pay);
        programs[_pid].rewardees[id].rewarded = true;
        emit WithdrawReward(_pid, id, msg.value);
    }

    function cumulatedRewardTo(uint _pid, uint _rid) public view returns(uint) {
        return programs[_pid].rewardees[_rid].total_rewarded;
    }

    function totalRewardBalance() public view returns(uint) {
        return address(this).balance;
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
    function transferProgramOwner(uint _pid, address _newOwner) public onlyProgramOwner(_pid) {
        require(_pid <= pCount);
        programs[_pid].progNewOwner = _newOwner;
    }
    function acceptProgramOwner(uint _pid) public {
        require(msg.sender == programs[_pid].progNewOwner);
        emit ProgramOwnerChanged(_pid, programs[_pid].progOwner, programs[_pid].progNewOwner);
        programs[_pid].progOwner = programs[_pid].progNewOwner;
        programs[_pid].progNewOwner = address(0);
    }
    function transferProgramManager(uint _pid, address _newManager) public onlyProgramManager(_pid) {
        require(_pid <= pCount);
        programs[_pid].progNewManager = _newManager;
    }
    function acceptProgramManager(uint _pid) public {
        require(msg.sender == programs[_pid].progNewManager);
        emit ProgramManagerChanged(_pid, programs[_pid].progManager, programs[_pid].progNewManager);
        programs[_pid].progManager = programs[_pid].progNewManager;
        programs[_pid].progNewManager = address(0);
    }
    function transferProgramRewarder(uint _pid, address _newRewarder) public onlyProgramRewarder(_pid) {
        require(_pid <= pCount);
        programs[_pid].progNewRewarder = _newRewarder;
    }
    function acceptProgramRewarder(uint _pid) public {
        require(msg.sender == programs[_pid].progNewRewarder);
        emit ProgramRewarderChanged(_pid, programs[_pid].progRewarder, programs[_pid].progNewRewarder);
        programs[_pid].progRewarder = programs[_pid].progNewRewarder;
        programs[_pid].progNewRewarder = address(0);
    }

    
////////////////PROGRAM VIEWER FUNCTIONS////////////////
    function programOwner(uint _pid) public view returns(address) {
        return programs[_pid].progManager;
    }
    function programManager(uint _pid) public view returns(address) {
        return programs[_pid].progManager;
    }
    function programRewarder(uint _pid) public view returns(address) {
        return programs[_pid].progRewarder;
    }
    function programBalance(uint _pid) public view returns(uint) {
        return programs[_pid].progBalance;
    }
    function startTime(uint _pid) public view returns(uint) {
        return programs[_pid].start_time;
    }
    function endTime(uint _pid) public view returns(uint) {
        return programs[_pid].days_left;
    }
    function RegisteredCount(uint _pid) public view returns(uint) {
        return programs[_pid].registeredCount;
    }
    function RewardedCount(uint _pid) public view returns(uint) {
        return programs[_pid].rewardedCount;
    }

    function registered(uint _pid, uint _rid) public view returns(bool) {
        address b = programs[_pid].rewardees[_rid].addr;
        return programs[_pid].rwd_info[b].registered;
    }
    function registered(uint _pid, address _addr) public view returns(bool) {
        return programs[_pid].rwd_info[_addr].registered;
    }
    function rewardeeID(uint _pid, address _addr) public view returns(uint) {
        return programs[_pid].rwd_info[_addr].rwdId;
    }
    function totalRewardedTo(uint _pid, uint _rid) public view returns(uint) {
        return programs[_pid].rewardees[_rid].total_rewarded;
    }

    function totalContractBalance() public view returns(uint) {
        return address(this).balance;
    }
    ////////////////INTERNAL FUNCTIONS//////////////////
    function lockProgram(uint _pid) public onlyProgramOwner(_pid){
        require(msg.sender == programs[_pid].progOwner);
        programs[_pid].progManager = address(0);
        emit LockedProgram(_pid, now);
    }
    
    function auto_reward(uint _pid) private {
        uint rc = programs[_pid].registeredCount; // number of rewardees less than 100
        uint pb = programs[_pid].progBalance; // balance of the program
        uint ra = rc.div(pb); // reward allotment
        for(uint temp = 0; temp < rc; temp++) {
            programs[_pid].rewardees[temp].addr.transfer(ra); //transfer each registered rewardee allotment
        }
    }
}