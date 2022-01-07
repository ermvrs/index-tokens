pragma solidity ^0.8.0;

//Index token strategy

import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "./IUniswapV2Router02.sol";
import "./IUniswapV2Factory.sol";
import "./IUniswapV2Pair.sol";

contract IndexStrategyV1 is Ownable, ERC20 {
    using SafeMath for uint256;

    event RouterChanged(IUniswapV2Router02 router, address changer);
    event MintingFeeChanged(uint256 fee);
    
    IUniswapV2Router02 public router; // router for price checks.
    IUniswapV2Factory public factory; // factory of dex.
    IERC20 public baseToken; // base Defi Token it always should be in index with minimum ratio.
    IERC20Metadata public stable; // stable token which all strategies indexed.

    uint256 public minBaseTokenRatio = 1000; // Minimum ratio of base token in index. 
    uint256 public mintingFee = 100; 
    uint256 public minLiquidity = 100000; // equivalent to 100000 * 10^decimals

    struct Strategy {
        IERC20 token;
        uint256 ratioBP; // base point
    }

    struct StrategyData { // just for an output
        IERC20 token;
        uint256 amount;
    }

    Strategy[] public strategies;

    constructor(Strategy[] memory _strategy, string memory _name, string memory _symbol, IUniswapV2Router02 _router, IUniswapV2Factory _factory, IERC20Metadata _stable, IERC20 _base) ERC20(_name, _symbol) {
        bool isBaseAdded = false;

        baseToken = _base;
        router = _router;
        factory = _factory;
        stable = _stable;

        uint8 decimals = stable.decimals();
        uint256 minLiqStable = minLiquidity.mul(10**decimals);

        for(uint i = 0; i < _strategy.length; i++) {
            require(address(_strategy[i].token) != address(0), "strategy address zero");
            if(_strategy[i].token == baseToken) {
                require(_strategy[i].ratioBP >= minBaseTokenRatio, "base token ratio low");
                isBaseAdded = true;
            }
            // check if every token has an liquidity.
            address pair = factory.getPair(address(stable), address(_strategy[i].token));
            require(pair != address(0), "pair not found for token");

            uint256 pairBalance = stable.balanceOf(pair);
            require(pairBalance >= minLiqStable, "pair liquidity too low");

        }
        if(!isBaseAdded) {
            revert();
        }
        // initialize index.
        strategies = _strategy;


    }

    // amount of token to mint
    function mint(uint256 _amount) public {
        
    }

    // View functions
    function getAmounts() public view returns(StrategyData[] memory) {
        StrategyData[] memory _balances;

        for(uint i = 0; i < strategies.length; i++) {
            uint256 balance = strategies[i].token.balanceOf(address(this));
            _balances[i] = StrategyData({
                token : strategies[i].token,
                amount : balance
            });
        }

        return _balances;
    }

    function getStableValue(IERC20 _token) public view returns(uint256) {
        // it will be calculated with getAmountsIn, it will cost us how much stable has to be paid to get amount token.
        address[] memory path;
        path[0] = address(_token);
        path[1] = address(stable);
        uint256[] memory amount = router.getAmountsIn(1 ether, path);
    }

    // Owner functions
    function setMintingFee(uint256 _fee) public onlyOwner {
        require(_fee <= 10000, "minting fee to high");
        mintingFee = _fee;

        emit MintingFeeChanged(_fee);
    }

    function setRouter(IUniswapV2Router02 _router) public onlyOwner {
        router = _router;

        emit RouterChanged(_router, msg.sender);
    }

}