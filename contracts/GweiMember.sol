pragma solidity ^0.4.24;

library SafeMath 
{
    function mul(uint256 a, uint256 b) internal pure returns (uint256) 
    {
        if (a == 0) 
        {
            return 0;
        }
        uint256 c = a * b;
        assert(c / a == b);
        return c;
    }

    function div(uint256 a, uint256 b) internal pure returns (uint256) 
    {
        uint256 c = a / b;
        return c;
    }

    function sub(uint256 a, uint256 b) internal pure returns (uint256) 
    {
        assert(b <= a);
        return a - b;
    }

    function add(uint256 a, uint256 b) internal pure returns (uint256) 
    {
        uint256 c = a + b;
        assert(c >= a);
        return c;
    }
}

contract ERC20Basic 
{
    function totalSupply() public view returns (uint256);
    function balanceOf(address who) public view returns (uint256);
    function transfer(address to, uint256 value) public returns (bool);
    event Transfer(address indexed from, address indexed to, uint256 value);
}

contract BasicToken is ERC20Basic 
{
    using SafeMath for uint256;

    mapping(address => uint256) balances;

    uint256 totalSupply_;
    uint256 forSale_;
    
    uint256 startTimestamp;
    uint256 loopTimestamp;
    uint256 authTimestamp;


    function totalSupply() public view returns (uint256) 
    {
        return totalSupply_;
    }

    function transfer(address _to, uint256 _value) public returns (bool) 
    {
        require(((now - startTimestamp) % loopTimestamp) < authTimestamp);
        require(_to != address(0));
        require(_value <= balances[msg.sender]);

        balances[msg.sender] = balances[msg.sender].sub(_value);
        balances[_to] = balances[_to].add(_value);
        emit Transfer(msg.sender, _to, _value);
        return true;
    }

    function balanceOf(address _owner) public view returns (uint256 balance) 
    {
        return balances[_owner];
    }
}

contract GweiMember is BasicToken 
{
    address owner;
    address reserveOwner;
    uint256 amountSold = uint256(0);

    uint256 priceStart0 = uint256(1 ether);
    uint256 priceStart1 = uint256(7 ether);
    uint256 priceStart2 = uint256(9 ether);
    uint256 priceStart3 = uint256(15 ether);

    uint256 amount1 = uint256(30);
    uint256 amount2 = uint256(50);
    uint256 amount3 = uint256(150);

    uint256 increase1 = uint256(priceStart1.sub(priceStart0)).div(amount1);
    uint256 increase2 = uint256(priceStart2.sub(priceStart1)).div(amount2);
    uint256 increase3 = uint256(priceStart3.sub(priceStart2)).div(amount3);

    uint256 discountPercent = uint256(10);

    struct Tracker {
        uint256 token;
        uint256 value;
        bool isDiscounted;
    }

    struct purchaseData {
        Tracker[] info;
        uint256 totalToken;
        uint256 totalValue;
        bool isDiscounted;
        address invitor;
    }

    event Purchase(
        address indexed buyer, 
        uint256 amout, 
        uint256 value
    );

    event PurchaseInvited(
        address indexed buyer, 
        address indexed invitor,
        uint256 amount, 
        uint256 value, 
        uint256 discountPercent 
    );

    address[] buyers;
    mapping (address => purchaseData) purchase;

    event TokenCreated(address tokenAddress);

    constructor(address _owner, address _reserveOwner) public 
    {
        require(_owner != address(0));
        require(_reserveOwner != address(0));

        owner = _owner;
        reserveOwner = _reserveOwner;

        totalSupply_ = uint256(460);
        forSale_ = uint256(230);
        
        startTimestamp = uint256(259200);
        loopTimestamp = uint256(604800);
        authTimestamp = uint256(86400);

        balances[owner] = forSale_;
        balances[reserveOwner] = totalSupply_.sub(forSale_);

        emit TokenCreated(address(this));
        emit Transfer(0x00, owner, balances[owner]);
        emit Transfer(0x00, reserveOwner, balances[reserveOwner]);
    }

    function calTokenPrice(uint256 _amountSold) internal view returns (uint256)
    {
        require(_amountSold >= 0);

        uint256 price;

        if(_amountSold < amount1)
        {
            price = priceStart0 + _amountSold * increase1;
        }
        else if (_amountSold < (amount1 + amount2))
        {
            price = priceStart1 + (_amountSold - amount1) * increase2; 
        }
        else if (_amountSold < (amount1 + amount2 + amount3))
        {
            price = priceStart2 + (_amountSold - amount1 - amount2) * increase3;
        }
        else
        {
            price = priceStart3; 
        }
        return price;
    }

    function calTokens(uint256 _value, bool _isDiscounted) internal view returns (uint256, uint256) 
    {
        uint256 remaining = _value;
        uint256 mAmountSold = amountSold;
        uint256 amount = uint256(0);
        uint256 tokenPrice;

        while (true)
        {
            if(_isDiscounted)
            {
                tokenPrice = calTokenPrice(mAmountSold).mul(100 - discountPercent).div(100);
            }
            else
            {
                tokenPrice = calTokenPrice(mAmountSold);
            }
            
            if(remaining >= tokenPrice)
            {
                remaining -= tokenPrice;
                amount++;
                mAmountSold++;
            }
            else
            {
                return (amount, remaining);
            }            
        }       
    }

    function addBuyer(address buyer) internal
    {
        for (uint256 i = 0; i < buyers.length; i++)
        {
            if (buyers[i] == buyer)
            {
                return;
            }
        }
        buyers.push(buyer);
    }

    function () public payable
    {
        require(msg.value > 0);

        uint256 amount;
        uint256 value;
        uint256 remaining;
        (amount, remaining) = calTokens(msg.value, false);
        value = msg.value - remaining;

        require(amount > 0);
        require(balances[owner] >= amount);

        balances[msg.sender] += amount;
        balances[owner] -= amount;
        amountSold += amount;
        emit Transfer(owner, msg.sender, amount);

        Tracker memory trace;
        trace.token = amount;
        trace.value = value;
        trace.isDiscounted = false;
        
        purchase[msg.sender].info.push(trace);
        purchase[msg.sender].totalToken += amount;
        purchase[msg.sender].totalValue += value;
        addBuyer(msg.sender);

        owner.transfer(value);

        if (remaining > 0)
        {
            msg.sender.transfer(remaining);
        }

        emit Purchase(msg.sender, value, amount);
    }

    function invitedPuchase(address invitor) public payable {
        require(msg.value > 0);
        require(purchase[invitor].totalToken >= 1);
        require(!purchase[msg.sender].isDiscounted);

        uint256 amount;
        uint256 value;
        uint256 remaining;
        uint256 discount;
        (amount, remaining) = calTokens(msg.value, true);
        value = msg.value - remaining;
        
        require(amount > 0);
        require(balances[owner] >= amount);

        discount = (value).div(100 - discountPercent).mul(discountPercent);
        
        balances[msg.sender] += amount;
        balances[owner] -= amount;
        amountSold += amount;
        emit Transfer(owner, msg.sender, amount);

        Tracker memory trace;
        trace.token = amount;
        trace.value = value;
        trace.isDiscounted = true;

        purchase[msg.sender].info.push(trace);
        purchase[msg.sender].totalToken += amount;
        purchase[msg.sender].totalValue += value;
        purchase[msg.sender].isDiscounted = true;
        purchase[msg.sender].invitor = invitor;
        addBuyer(msg.sender);
        
        invitor.transfer(discount);
        owner.transfer(value.sub(discount));
        if (remaining > 0)
        {
            msg.sender.transfer(remaining);
        }

        emit PurchaseInvited(msg.sender, invitor, value, amount, discountPercent);
    }   

    function name() public pure returns (string) 
    {
        return "GweiNetwork Membership";
    }

    function symbol() public pure returns (string) 
    {
        return "GNM";
    }

    function decimals() public pure returns (uint256) 
    {
        return uint256(0);
    }

    function isToken() public pure returns (bool) 
    {
        return true;
    }

    function setPrice(
        uint256 _priceStart0,
        uint256 _priceStart1,
        uint256 _priceStart2,
        uint256 _priceStart3,
        uint256 _amount1,
        uint256 _amount2,
        uint256 _amount3
    ) public {
        require(msg.sender == owner);

        priceStart0 = _priceStart0;
        priceStart1 = _priceStart1;
        priceStart2 = _priceStart2;
        priceStart3 = _priceStart3;
        amount1 = _amount1;
        amount2 = _amount2;
        amount3 = _amount3;
    }

    function setAuthTime(uint256 _startTimestamp, uint256 _loopTimestamp, uint256 _authTimestamp) public
    {
        require(msg.sender == owner);
        startTimestamp = _startTimestamp;
        loopTimestamp = _loopTimestamp;
        authTimestamp = _authTimestamp;
    }

    function updateDiscountPercent(uint256 _discountPercent) public
    {
        require(_discountPercent > 0 && _discountPercent < 50);
        discountPercent = _discountPercent;
    }

    function claimBalance() public 
    {
        require(msg.sender == owner);
        owner.transfer(address(this).balance);
    }

    function tokenBalance() public view returns (uint256) 
    {
        return address(this).balance;
    }

    function getBuyers() public view returns (address[])
    {
        return buyers;
    }

    function getPurchase(address buyer) public view returns (uint256, uint256, bool, address) 
    {
        uint256 totalToken = purchase[buyer].totalToken;
        uint256 totalValue = purchase[buyer].totalValue;
        bool isDiscounted = purchase[buyer].isDiscounted;
        address invitor = purchase[buyer].invitor;
        
        return (totalToken, totalValue, isDiscounted, invitor);
    }
    
    function getPurchaseTrace(address buyer) public view returns (uint256[], uint256[], bool[]) 
    {
        uint256[] memory tokenTrace = new uint[](purchase[buyer].info.length);
        uint256[] memory valueTrace = new uint[](purchase[buyer].info.length);
        bool[] memory isDiscountedTrace = new bool[](purchase[buyer].info.length);
        
        for (uint i = 0; i < purchase[buyer].info.length; i++) {
            Tracker storage info = purchase[buyer].info[i];
            tokenTrace[i] = info.token;
            valueTrace[i] = info.value;
            isDiscountedTrace[i] = info.isDiscounted;
        }
        
        return (tokenTrace, valueTrace, isDiscountedTrace);
    }

    function getInfo() public view returns (uint256, uint256, uint256, uint256, uint256) 
    {
        return (balances[owner], amountSold, startTimestamp, loopTimestamp, authTimestamp);
    }

    function calPurchaseCost(uint256 tokenAmount, bool isDiscounted) external view returns (uint256)
    {
        uint256 cost = uint256(0);

        for (uint256 i = 0; i < tokenAmount; i++)
        {
            cost += calTokenPrice(amountSold + i);
        }

        if (isDiscounted)
        {
            return (cost - cost.div(100).mul(discountPercent));
        }
        else
        {
            return cost;   
        }
    }

    function getTokenPrice() public view returns (uint256)
    {
        return calTokenPrice(amountSold);
    }

    function canTransfer() public view returns (bool, uint256, uint256, uint256)
    {
        return (
            ((now - startTimestamp) % loopTimestamp) < authTimestamp,
            now, 
            authTimestamp, 
            ((now - startTimestamp) % loopTimestamp)
        );
    }
}

