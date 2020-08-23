// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.6.8;
pragma experimental ABIEncoderV2;

interface iERC20 {
    function name() external view returns (string memory);
    function symbol() external view returns (string memory);
    function decimals() external view returns (uint);
    function totalSupply() external view returns (uint);
    function balanceOf(address account) external view returns (uint);
    function transfer(address, uint) external returns (bool);
    function allowance(address owner, address spender) external view returns (uint);
    function approve(address, uint) external returns (bool);
    function transferFrom(address, address, uint) external returns (bool);
    event Transfer(address indexed from, address indexed to, uint value);
    event Approval(address indexed owner, address indexed spender, uint value);
}
interface iVADER {
    function secondsPerEra() external view returns (uint);
    function DAO() external view returns (address);
}
interface iUTILS {
    function calcPart(uint bp, uint total) external pure returns (uint part);
    function calcShare(uint part, uint total, uint amount) external pure returns (uint share);
    function calcSwapOutput(uint x, uint X, uint Y) external pure returns (uint output);
    function calcSwapFee(uint x, uint X, uint Y) external pure returns (uint output);
    function calcStakeUnits(uint a, uint A, uint v, uint S) external pure returns (uint units);
    function calcAsymmetricShare(uint s, uint T, uint A) external pure returns (uint share);
    function getPoolAge(address token) external view returns(uint age);
    function getPoolShare(address token, uint units) external view returns(uint baseAmt, uint tokenAmt);
    function getPoolShareAssym(address token, uint units, bool toBase) external view returns(uint baseAmt, uint tokenAmt, uint outputAmt);
}
interface iVDAO {
    function ROUTER() external view returns(address);
}

// SafeMath
library SafeMath {

    function add(uint a, uint b) internal pure returns (uint)   {
        uint c = a + b;
        assert(c >= a);
        return c;
    }

    function mul(uint a, uint b) internal pure returns (uint) {
        if (a == 0) {
            return 0;
        }
        uint c = a * b;
        require(c / a == b, "SafeMath");
        return c;
    }

    function sub(uint256 a, uint256 b) internal pure returns (uint256) {
        return sub(a, b, "SafeMath");
    }
    function sub(uint256 a, uint256 b, string memory errorMessage) internal pure returns (uint256) {
        require(b <= a, errorMessage);
        uint256 c = a - b;
        return c;
    }

    function div(uint256 a, uint256 b) internal pure returns (uint256) {
        return div(a, b, "SafeMath");
    }
    function div(uint256 a, uint256 b, string memory errorMessage) internal pure returns (uint256) {
        require(b > 0, errorMessage);
        uint256 c = a / b;
        return c;
    }
}

contract VPool_Vether is iERC20 {
    using SafeMath for uint;

    address public VETHER;
    iVDAO public VDAO;
    iUTILS public UTILS;
    address public TOKEN;

    uint public one = 10**18;

    // ERC-20 Parameters
    string _name; string _symbol;
    uint public override decimals; uint public override totalSupply;
    // ERC-20 Mappings
    mapping(address => uint) private _balances;
    mapping(address => mapping(address => uint)) private _allowances;

    uint public genesis;
    uint public baseAmt;
    uint public tokenAmt;
    uint public baseAmtStaked;
    uint public tokenAmtStaked;
    uint public fees;
    uint public volume;
    uint public txCount;
    
    // Only Router can execute
    modifier onlyRouter() {
        _isRouter();
        _;
    }

    function _isRouter() internal view {
        require(msg.sender == VDAO.ROUTER(), "RouterErr");
    }

    constructor (address _vader, iVDAO _vDao, iUTILS _utils, address _token) public payable {

        VETHER = _vader;
        UTILS = _utils;
        TOKEN = _token;
        VDAO = _vDao;

        string memory poolName = "VetherPoolV1-";
        string memory poolSymbol = "VPT1-";

        if(_token == address(0)){
            _name = string(abi.encodePacked(poolName, "Ethereum"));
            _symbol = string(abi.encodePacked(poolSymbol, "ETH"));
        } else {
            _name = string(abi.encodePacked(poolName, iERC20(_token).name()));
            _symbol = string(abi.encodePacked(poolSymbol, iERC20(_token).symbol()));
        }
        
        decimals = 18;
        genesis = now;
    }

    function _checkApprovals() external onlyRouter{
        if(iERC20(VETHER).allowance(address(this), VDAO.ROUTER()) == 0){
            if(TOKEN != address(0)){
                iERC20(TOKEN).approve(VDAO.ROUTER(), (2**256)-1);
            }
        iERC20(VETHER).approve(VDAO.ROUTER(), (2**256)-1);
        }
    }

    receive() external payable {}

    //========================================iERC20=========================================//
    function name() public view override returns (string memory) {
        return _name;
    }
    function symbol() public view override returns (string memory) {
        return _symbol;
    }

    function balanceOf(address account) public view override returns (uint256) {
        return _balances[account];
    }
    function allowance(address owner, address spender) public view virtual override returns (uint256) {
        return _allowances[owner][spender];
    }
    // iERC20 Transfer function
    function transfer(address to, uint value) public override returns (bool success) {
        __transfer(msg.sender, to, value);
        return true;
    }
    // iERC20 Approve function
    function approve(address spender, uint256 amount) public virtual override returns (bool) {
        __approve(msg.sender, spender, amount);
        return true;
    }
    function __approve(address owner, address spender, uint256 amount) internal virtual {
        _allowances[owner][spender] = amount;
        emit Approval(owner, spender, amount);
    }
    // iERC20 TransferFrom function
    function transferFrom(address from, address to, uint value) public override returns (bool success) {
        require(value <= _allowances[from][msg.sender], 'AllowanceErr');
        _allowances[from][msg.sender] = _allowances[from][msg.sender].sub(value);
        __transfer(from, to, value);
        return true;
    }

    // Internal transfer function
    function __transfer(address _from, address _to, uint _value) private {
        require(_balances[_from] >= _value, 'BalanceErr');
        require(_balances[_to] + _value >= _balances[_to], 'BalanceErr');
        _balances[_from] =_balances[_from].sub(_value);
        _balances[_to] += _value;
        emit Transfer(_from, _to, _value);
    }

    // Router can mint
    function _mint(address account, uint256 amount) external onlyRouter {
        totalSupply = totalSupply.add(amount);
        _balances[account] = _balances[account].add(amount);
        // iVDAO vdao = iVDAO(iVADER(VETHER).DAO());
        _allowances[account][VDAO.ROUTER()] += amount;
        emit Transfer(address(0), account, amount);
    }
    // Burn supply
    function burn(uint256 amount) public virtual {
        __burn(msg.sender, amount);
    }
    function burnFrom(address from, uint256 value) public virtual {
        require(value <= _allowances[from][msg.sender], 'AllowanceErr');
        _allowances[from][msg.sender] = _allowances[from][msg.sender].sub(value);
        __burn(from, value);
    }
    // Router can burn
    function _burn(address from, uint256 value) external onlyRouter {
        __burn(from, value);
    }
    function __burn(address account, uint256 amount) internal virtual {
        _balances[account] = _balances[account].sub(amount, "BalanceErr");
        totalSupply = totalSupply.sub(amount);
        emit Transfer(account, address(0), amount);
    }

    // TransferTo function
    function transferTo(address recipient, uint256 amount) public returns (bool) {
        __transfer(tx.origin, recipient, amount);
        return true;
    }

    // ETH Transfer function
    function transferETH(address payable to, uint value) public payable onlyRouter returns (bool success) {
        to.call{value:value}(""); 
        return true;
    }

    function sync() public {
        if (TOKEN == address(0)) {
            tokenAmt = address(this).balance;
        } else {
            tokenAmt = iERC20(TOKEN).balanceOf(address(this));
        }
    }

    //==================================================================================//
    // Dividend functions

    function add(address token, uint amount) public returns (bool success) {
        if(token == VETHER){
            iERC20(VETHER).transferFrom(msg.sender, address(this), amount);
            baseAmt = baseAmt.add(amount);
            return true;
        } else if (token == TOKEN){
            iERC20(TOKEN).transferFrom(msg.sender, address(this), amount);
            tokenAmt = tokenAmt.add(amount); 
            return true;
        } else {
            return false;
        }
    } 

    //==================================================================================//
    // Data Model
    function _incrementPoolBalances(uint _baseAmt, uint _tokenAmt)  external onlyRouter  {
        baseAmt += _baseAmt;
        tokenAmt += _tokenAmt;
        baseAmtStaked += _baseAmt;
        tokenAmtStaked += _tokenAmt; 
    }
    function _setPoolBalances(uint _baseAmt, uint _tokenAmt, uint _baseAmtStaked, uint _tokenAmtStaked)  external onlyRouter  {
        baseAmtStaked = _baseAmtStaked;
        tokenAmtStaked = _tokenAmtStaked; 
        __setPool(_baseAmt, _tokenAmt);
    }
    function _setPoolAmounts(uint _baseAmt, uint _tokenAmt)  external onlyRouter  {
        __setPool(_baseAmt, _tokenAmt); 
    }
    function __setPool(uint _baseAmt, uint _tokenAmt) internal  {
        baseAmt = _baseAmt;
        tokenAmt = _tokenAmt; 
    }

    function _decrementPoolBalances(uint _baseAmt, uint _tokenAmt)  external onlyRouter  {
        uint _unstakedBase = UTILS.calcShare(_baseAmt, baseAmt, baseAmtStaked);
        uint _unstakedToken = UTILS.calcShare(_tokenAmt, tokenAmt, tokenAmtStaked);
        baseAmtStaked = baseAmtStaked.sub(_unstakedBase);
        tokenAmtStaked = tokenAmtStaked.sub(_unstakedToken); 
        __decrementPool(_baseAmt, _tokenAmt); 
    }
 
    function __decrementPool(uint _baseAmt, uint _tokenAmt) internal  {
        baseAmt = baseAmt.sub(_baseAmt);
        tokenAmt = tokenAmt.sub(_tokenAmt); 
    }

    function _addPoolMetrics(uint _volume, uint _fee) external onlyRouter  {
        txCount += 1;
        volume += _volume;
        fees += _fee;
    }

    //==================================================================================//
    // Helper functions

    function calcValueInBase(uint a) public view returns (uint value){
       return (a.mul(baseAmt)).div(tokenAmt);
    }

    function calcValueInToken(uint v) public view returns (uint value){
        return (v.mul(tokenAmt)).div(baseAmt);
    }

   function calcTokenPPinBase(uint amount) public view returns (uint output){
        return  UTILS.calcSwapOutput(amount, tokenAmt, baseAmt);
    }

    function calcBasePPinToken(uint amount) public view returns (uint output){
        return  UTILS.calcSwapOutput(amount, baseAmt, tokenAmt);
    }
}

contract VRouter_Vether {

    using SafeMath for uint;

    address public VETHER;
    iVDAO public VDAO;
    iUTILS public UTILS;
    address public DEPLOYER;

    uint public VETH_CAP; 

    uint public totalStaked; 
    uint public totalVolume;
    uint public totalFees;
    uint public unstakeTx;
    uint public stakeTx;
    uint public swapTx;

    address[] public arrayTokens;
    mapping(address=>address payable) private mapToken_Pool;
    mapping(address=>bool) public isPool;

    event NewPool(address token, address pool, uint genesis);
    event Staked(address member, uint inputBase, uint inputToken, uint unitsIssued);
    event Unstaked(address member, uint outputBase, uint outputToken, uint unitsClaimed);
    event Swapped(address tokenFrom, address tokenTo, uint inputAmount, uint transferAmount, uint outputAmount, uint fee, address recipient);
    // event NewEra(uint256 currentEra, uint256 nextEraTime, uint256 reserve);

// Only Deployer can execute
    modifier onlyDeployer() {
        require(msg.sender == DEPLOYER, "DeployerErr");
        _;
    }

    constructor (address _vader, address _vDao, address _utils) public payable {
        VETHER = _vader;
        VDAO = iVDAO(_vDao);
        UTILS = iUTILS(_utils);
        DEPLOYER = msg.sender;
        VETH_CAP = 20000*10**18;
    }

    function migrateRouterData(address oldRouter) public onlyDeployer {
        totalStaked = VRouter_Vether(oldRouter).totalStaked();
        totalVolume = VRouter_Vether(oldRouter).totalVolume();
        totalFees = VRouter_Vether(oldRouter).totalFees();
        unstakeTx = VRouter_Vether(oldRouter).unstakeTx();
        stakeTx = VRouter_Vether(oldRouter).stakeTx();
        swapTx = VRouter_Vether(oldRouter).swapTx();
    }

    function migrateTokenData(address oldRouter) public onlyDeployer {
        uint tokenCount = VRouter_Vether(oldRouter).tokenCount();
        for(uint i = 0; i<tokenCount; i++){
            address token = VRouter_Vether(oldRouter).getToken(i);
            address payable pool = VRouter_Vether(oldRouter).getPool(token);
            isPool[pool] = true;
            arrayTokens.push(token);
            mapToken_Pool[token] = pool;
        }
    }

    function updateDAO(address _vDao) public onlyDeployer {
        VDAO = iVDAO(_vDao);
    }

    function setCap(uint veth_cap) public onlyDeployer {
        VETH_CAP = veth_cap;
    }

    function purgeDeployer() public onlyDeployer {
        DEPLOYER = address(0);
    }

    function createPool(uint inputBase, uint inputToken, address token) public payable returns(address payable pool){
        require(getPool(token) == address(0), "CreateErr");
        require(token != VETHER, "Must not be Vader");
        require((inputToken > 0 && inputBase > 0), "Must get tokens for both");
        VPool_Vether newPool = new VPool_Vether(VETHER, VDAO, UTILS, token);
        pool = payable(address(newPool));
        uint _actualInputToken = _handleTransferIn(token, inputToken, pool);
        uint _actualInputBase = _handleTransferIn(VETHER, inputBase, pool);
        mapToken_Pool[token] = pool;
        arrayTokens.push(token);
        isPool[pool] = true;
        totalStaked += _actualInputBase;
        stakeTx += 1;
        _handleStake(pool, _actualInputBase, _actualInputToken, msg.sender);
        emit NewPool(token, pool, now);
        return pool;
    }

    //==================================================================================//
    // Staking functions

    function stake(uint inputBase, uint inputToken, address token) public payable returns (uint units) {
        units = stakeForMember(inputBase, inputToken, token, msg.sender);
        return units;
    }

    function stakeForMember(uint inputBase, uint inputToken, address token, address member) public payable returns (uint units) {
        address payable pool = getPool(token);
        uint _actualInputToken = _handleTransferIn(token, inputToken, pool);
        uint _actualInputBase = _handleTransferIn(VETHER, inputBase, pool);
        units = _handleStake(pool, _actualInputBase, _actualInputToken, member);
        emit Staked(member, _actualInputBase, _actualInputToken, units);
        totalStaked += _actualInputBase;
        stakeTx += 1;
        return units;
    }


    function _handleStake(address payable pool, uint _baseAmt, uint _tokenAmt, address _member) internal returns (uint _units) {
        require(totalStaked.add(_baseAmt) <= VETH_CAP, "Exceeds cap");
        VPool_Vether(pool)._checkApprovals();
        uint _S = VPool_Vether(pool).baseAmt().add(_baseAmt);
        uint _A = VPool_Vether(pool).tokenAmt().add(_tokenAmt);
        VPool_Vether(pool)._incrementPoolBalances(_baseAmt, _tokenAmt);                                                  
        _units = UTILS.calcStakeUnits(_tokenAmt, _A, _baseAmt, _S);  
        VPool_Vether(pool)._mint(_member, _units);
        return _units;
    }

    //==================================================================================//
    // Unstaking functions

    // Unstake % for self
    function unstake(uint basisPoints, address token) public returns (bool success) {
        require((basisPoints > 0 && basisPoints <= 10000), "InputErr");
        uint _units = UTILS.calcPart(basisPoints, iERC20(getPool(token)).balanceOf(msg.sender));
        unstakeExact(_units, token);
        return true;
    }

    // Unstake an exact qty of units
    function unstakeExact(uint units, address token) public returns (bool success) {
        address payable pool = getPool(token);
        address payable member = msg.sender;
        (uint _outputBase, uint _outputToken) = UTILS.getPoolShare(token, units);
        _handleUnstake(pool, units, _outputBase, _outputToken, member);
        emit Unstaked(member, _outputBase, _outputToken, units);
        totalStaked = totalStaked.sub(_outputBase);
        unstakeTx += 1;
        _handleTransferOut(token, _outputToken, pool, member);
        _handleTransferOut(VETHER, _outputBase, pool, member);
        return true;
    }

    // // Unstake % Asymmetrically
    function unstakeAsymmetric(uint basisPoints, bool toBase, address token) public returns (uint outputAmount){
        uint _units = UTILS.calcPart(basisPoints, iERC20(getPool(token)).balanceOf(msg.sender));
        outputAmount = unstakeExactAsymmetric(_units, toBase, token);
        return outputAmount;
    }
    // Unstake Exact Asymmetrically
    function unstakeExactAsymmetric(uint units, bool toBase, address token) public returns (uint outputAmount){
        address payable pool = getPool(token);
        require(units < iERC20(pool).totalSupply(), "InputErr");
        (uint _outputBase, uint _outputToken, uint _outputAmount) = UTILS.getPoolShareAssym(token, units, toBase);
        _handleUnstake(pool, units, _outputBase, _outputToken, msg.sender);
        emit Unstaked(msg.sender, _outputBase, _outputToken, units);
        totalStaked = totalStaked.sub(_outputBase);
        unstakeTx += 1;
        _handleTransferOut(token, _outputToken, pool, msg.sender);
        _handleTransferOut(VETHER, _outputBase, pool, msg.sender);
        return _outputAmount;
    }

    function _handleUnstake(address payable pool, uint _units, uint _outputBase, uint _outputToken, address _member) internal returns (bool success) {
        VPool_Vether(pool)._checkApprovals();
        VPool_Vether(pool)._decrementPoolBalances(_outputBase, _outputToken);
        VPool_Vether(pool)._burn(_member, _units);
        return true;
    } 

    //==================================================================================//
    // Universal Swapping Functions

    function buy(uint amount, address token) public payable returns (uint outputAmount, uint fee){
        (outputAmount, fee) = buyTo(amount, token, msg.sender);
        return (outputAmount, fee);
    }
    function buyTo(uint amount, address token, address payable member) public payable returns (uint outputAmount, uint fee) {
        address payable pool = getPool(token);
        VPool_Vether(pool)._checkApprovals();
        uint _actualAmount = _handleTransferIn(VETHER, amount, pool);
        (outputAmount, fee) = _swapBaseToToken(pool, _actualAmount);
        totalStaked += _actualAmount;
        totalVolume += _actualAmount;
        totalFees += VPool_Vether(pool).calcValueInBase(fee);
        swapTx += 1;
        _handleTransferOut(token, outputAmount, pool, member);
        emit Swapped(VETHER, token, _actualAmount, 0, outputAmount, fee, member);
        return (outputAmount, fee);
    }

    function sell(uint amount, address token) public payable returns (uint outputAmount, uint fee){
        (outputAmount, fee) = sellTo(amount, token, msg.sender);
        return (outputAmount, fee);
    }
    function sellTo(uint amount, address token, address payable member) public payable returns (uint outputAmount, uint fee) {
        address payable pool = getPool(token);
        VPool_Vether(pool)._checkApprovals();
        uint _actualAmount = _handleTransferIn(token, amount, pool);
        (outputAmount, fee) = _swapTokenToBase(pool, _actualAmount);
        totalStaked = totalStaked.sub(outputAmount);
        totalVolume += outputAmount;
        totalFees += fee;
        swapTx += 1;
        _handleTransferOut(VETHER, outputAmount, pool, member);
        emit Swapped(token, VETHER, _actualAmount, 0, outputAmount, fee, member);
        return (outputAmount, fee);
    }

    function swap(uint inputAmount, address fromToken, address toToken) public payable returns (uint outputAmount, uint fee) {
        require(fromToken != toToken, "InputErr");
        address payable poolFrom = getPool(fromToken); address payable poolTo = getPool(toToken);
        VPool_Vether(poolFrom)._checkApprovals();
        VPool_Vether(poolTo)._checkApprovals();
        uint _actualAmount = _handleTransferIn(fromToken, inputAmount, poolFrom);
        uint _transferAmount = 0;
        if(fromToken == VETHER){
            (outputAmount, fee) = _swapBaseToToken(poolFrom, _actualAmount);      // Buy to token
            totalStaked += _actualAmount;
            totalVolume += _actualAmount;
        } else if(toToken == VETHER) {
            (outputAmount, fee) = _swapTokenToBase(poolFrom,_actualAmount);   // Sell to token
            totalStaked = totalStaked.sub(outputAmount);
            totalVolume += outputAmount;
        } else {
            (uint _yy, uint _feey) = _swapTokenToBase(poolFrom, _actualAmount);             // Sell to VETHER
            uint _actualYY = _handleTransferOver(VETHER, poolFrom, poolTo, _yy);
            totalStaked = totalStaked.add(_actualYY).sub(_actualAmount);
            totalVolume += _yy; totalFees += _feey;
            (uint _zz, uint _feez) = _swapBaseToToken(poolTo, _actualYY);              // Buy to token
            totalFees += VPool_Vether(poolTo).calcValueInBase(_feez);
            _transferAmount = _actualYY; outputAmount = _zz; 
            fee = _feez + VPool_Vether(poolTo).calcValueInToken(_feey);
        }
        swapTx += 1;
        _handleTransferOut(toToken, outputAmount, poolTo, msg.sender);
        emit Swapped(fromToken, toToken, _actualAmount, _transferAmount, outputAmount, fee, msg.sender);
        return (outputAmount, fee);
    }

    function _swapBaseToToken(address payable pool, uint _x) internal returns (uint _y, uint _fee){
        uint _X = VPool_Vether(pool).baseAmt();
        uint _Y = VPool_Vether(pool).tokenAmt();
        _y =  UTILS.calcSwapOutput(_x, _X, _Y);
        _fee = UTILS.calcSwapFee(_x, _X, _Y);
        VPool_Vether(pool)._setPoolAmounts(_X.add(_x), _Y.sub(_y));
        _updatePoolMetrics(pool, _y+_fee, _fee, false);
        return (_y, _fee);
    }

    function _swapTokenToBase(address payable pool, uint _x) internal returns (uint _y, uint _fee){
        uint _X = VPool_Vether(pool).tokenAmt();
        uint _Y = VPool_Vether(pool).baseAmt();
        _y =  UTILS.calcSwapOutput(_x, _X, _Y);
        _fee = UTILS.calcSwapFee(_x, _X, _Y);
        VPool_Vether(pool)._setPoolAmounts(_Y.sub(_y), _X.add(_x));
        _updatePoolMetrics(pool, _y+_fee, _fee, true);
        return (_y, _fee);
    }

    function _updatePoolMetrics(address payable pool, uint _txSize, uint _fee, bool _toBase) internal {
        if(_toBase){
            VPool_Vether(pool)._addPoolMetrics(_txSize, _fee);
        } else {
            uint _txBase = VPool_Vether(pool).calcValueInBase(_txSize);
            uint _feeBase = VPool_Vether(pool).calcValueInBase(_fee);
            VPool_Vether(pool)._addPoolMetrics(_txBase, _feeBase);
        }
    }

    //==================================================================================//
    // Token Transfer Functions

    function _handleTransferIn(address _token, uint _amount, address _pool) internal returns(uint actual){
        if(_amount > 0) {
            if(_token == address(0)){
                require((_amount == msg.value), "InputErr");
                payable(_pool).call{value:_amount}(""); 
                actual = _amount;
            } else {
                uint startBal = iERC20(_token).balanceOf(_pool); 
                iERC20(_token).transferFrom(msg.sender, _pool, _amount); 
                actual = iERC20(_token).balanceOf(_pool).sub(startBal);
            }
        }
    }

    function _handleTransferOut(address _token, uint _amount, address _pool, address payable _recipient) internal {
        if(_amount > 0) {
            if (_token == address(0)) {
                VPool_Vether(payable(_pool)).transferETH(_recipient, _amount);
            } else {
                iERC20(_token).transferFrom(_pool, _recipient, _amount);
            }
        }
    }

    function _handleTransferOver(address _token, address _from, address _to, uint _amount) internal returns(uint actual){
        if(_amount > 0) {
            uint startBal = iERC20(_token).balanceOf(_to); 
            iERC20(_token).transferFrom(_from, _to, _amount); 
            actual = iERC20(_token).balanceOf(_to).sub(startBal);
        }
    }
    

    //======================================HELPERS========================================//
    // Helper Functions

    function getPool(address token) public view returns(address payable pool){
        return mapToken_Pool[token];
    }

    function tokenCount() public view returns(uint){
        return arrayTokens.length;
    }

    function getToken(uint i) public view returns(address){
        return arrayTokens[i];
    }

}