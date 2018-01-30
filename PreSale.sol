pragma solidity ^0.4.15;

import './Token.sol';


/**
 * @title SMAG Pre-Sale
 */

contract PreSale is Ownable{

    using SafeMath for uint256;

    Token public token;

    uint256 public tokenPrice;  // Fix Price during Pre-Sale 0,00002 ETH
    uint256 public minimumSell; // Minimum Wei one can participate 
    uint256 public maximumSell; // Maximum Wei one can participate at all
    
    address public bounty;

    // Maximum Number of Tokens will be generated during Pre-Sale
    uint256 constant internal PRE_ICO_LIMIT = 10000000 * (10 ** uint256(18)); // 10M SMAGs

    /**
    * ICO Phases.
    *
    * - PreStart:   tokens are not yet sold/issued
    * - PreIco1:    new tokens sold/issued with a bonus rate of 100%
    * - PreIco2:    new tokens sold/issued with a bonus rate of 70%
    * - PreIco3:    new tokens sold/issued with a bonus rate of 30%
    * - PreIco4:    new tokens sold/issued with a bonus rate of 0%
    * - AfterPreIco:new tokens can not be not be sold/issued any longer
    */
    
    enum Phases {PreStart, PreIco1, PreIco2, PreIco3, PreIco4, AfterPreIco}

    uint64 constant internal DURATION_1 = 24 hours;
    uint64 constant internal DURATION_2 = 48 hours;
    uint64 constant internal DURATION_3 = 72 hours;
    uint64 constant internal DURATION_4 = 96 hours;

    uint64 constant internal PRE_ICO_DURATION = 240 hours;

    struct Rates {
        uint256 toSender;
        uint256 toOwner;
        uint256 toBounty;
        uint256 total;
    }

    event NewTokens(uint256 amount);
    event NewFunds(address funder, uint256 value);
    event NewPhase(Phases phase);

    // current Phase
    Phases public phase = Phases.PreStart;

    // Timestamps limiting duration of Phases, in seconds since Unix epoch.
    uint64 public preICOStartTime;      // when Pre-ICO starts
    uint64 public preICOclosingTime;    // when Pre-ICO ends

    uint256 public totalProceeds;

    /*
     * @dev constructor
     * @param _preICOStartTime Timestamp when the Pre-ICO shall start.
     */
    function PreSale(uint64 _preICOStartTime, address _bounty ) payable {
        require(_preICOStartTime > now);

        token = new Token();

        preICOStartTime     = _preICOStartTime;
        preICOclosingTime   = preICOStartTime + PRE_ICO_DURATION;
        
        bounty              = _bounty;
        tokenPrice          = 2  * (10 ** uint256(13)); //  0,00002 ETH Fix Price during Pre-Sale
        minimumSell         = 1  * (10 ** uint256(17)); //  0,10000 ETH
        maximumSell         = 10 * (10 ** uint256(18)); // 10,00000 ETH
    }

    /*
     * @dev Fallback function delegates the request to create().
     */
    function () payable external {
        create();
    }

    /**
     * @dev Mint tokens and add them to the balance of the message.sender.
     * Additional tokens are minted and added to the bounty balances.
     * @return success/failure
     */
    function create() payable whenNotClosed public returns (bool success) {
        require(msg.value > 0);
        require(now >= preICOStartTime);
        require(msg.value >= minimumSell);
        require(msg.value <= maximumSell);
        
        uint256 weiToParticipate = msg.value;
        uint256 tokensToIssue = weiToParticipate.div(tokenPrice);

        adjustPhaseBasedOnTime();

        if (phase != Phases.AfterPreIco) {

            Rates memory rates = getRates();

            token.mint(msg.sender, (tokensToIssue.mul(rates.toSender) * (10 ** uint256(16))));   // Bonus    Tokens to be minted
            token.mint(bounty,     (tokensToIssue.mul(rates.toBounty) * (10 ** uint256(16))));   // Bounty   Tokens to be minted

            // ETH transfers
            totalProceeds = totalProceeds.add(weiToParticipate);
            
            // Logging
            NewFunds(msg.sender, weiToParticipate);

        } else {
            //setWithdrawal(owner, weiToParticipate);
        }
        return true;
    }

    /**
     * @dev Send the value (ethers) that the contract holds to the owner address.
     */
    function returnWei() onlyOwner external {
        owner.transfer(this.balance);
    }

    function adjustPhaseBasedOnTime() internal {

        if (now >= preICOclosingTime) {
            if (phase != Phases.AfterPreIco) {
                phase = Phases.AfterPreIco;
            }
        } else if (now >= preICOStartTime + DURATION_1 + DURATION_2 + DURATION_3) {
            if (phase != Phases.PreIco4) {
                phase = Phases.PreIco4;
            }
		} else if (now >= preICOStartTime + DURATION_1 + DURATION_2 ) {
            if (phase != Phases.PreIco3) {
                phase = Phases.PreIco3;
            }
        } else if (now >= preICOStartTime + DURATION_1 ) {
            if (phase != Phases.PreIco2) {
                phase = Phases.PreIco2;
            }
		} else if (now >= preICOStartTime) {
            if (phase != Phases.PreIco1) {
                phase = Phases.PreIco1;
            }
        }
    }

    function getRates() internal returns (Rates rates) {
		if (phase == Phases.PreIco1) {
            rates.toSender 	= 200;
            rates.toBounty 	= 3;
        } else if (phase == Phases.PreIco2) {
            rates.toSender 	= 190;
            rates.toBounty 	= 3;
        } else if (phase == Phases.PreIco3) {
            rates.toSender 	= 180;
            rates.toBounty 	= 3;
        } else if (phase == Phases.PreIco4) {
            rates.toSender 	= 150;
            rates.toBounty 	= 3;
        } 
        return rates;
    }
    
    /**
     * @dev Throws if called when ICO is active.
     */
    modifier whenClosed() {
        require(phase == Phases.AfterPreIco);
        _;
    }

    /**
     * @dev Throws if called when ICO is completed.
     */
    modifier whenNotClosed() {
        require(phase != Phases.AfterPreIco);
        _;
    }

    /**
     * @dev Throws if called by the owner before ICO is completed.
     */
    modifier limitForOwner() {
        require((msg.sender != owner) || (phase == Phases.AfterPreIco));
        _;
    }
}