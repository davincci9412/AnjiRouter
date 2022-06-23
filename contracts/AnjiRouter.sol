pragma solidity ^0.6.12;

import './libraries/PancakeLibrary.sol';
import './libraries/SafeMath.sol';
import './libraries/TransferHelper.sol';
import './interfaces/IPancakeRouter02.sol';
import './interfaces/IERC20.sol';
import './interfaces/IWETH.sol';

contract AnjiRouter is IPancakeRouter02 {
    using SafeMath for uint;

    address public immutable override factory;
    address public immutable override WETH;

    address public owner;

    address public BUSD;
    address public anji;
    uint256 private busdThreshold;
    address public feeAddress;
    bool public feeOFF = false;

    modifier onlyOwner() {
        require(msg.sender == owner, "Ownership required."); _;
    }

    modifier ensure(uint deadline) {
        require(deadline >= block.timestamp, 'AnjiRouter: EXPIRED');
        _;
    }

    constructor(address _factory, address _WETH, address _BUSD) public {
        factory = _factory;
        WETH = _WETH;
        BUSD = _BUSD;
        feeAddress = msg.sender;
        owner = msg.sender;
    }

    receive() external payable {
        assert(msg.sender == WETH); // only accept ETH via fallback from the WETH contract
    }

    function setAnjiAddress(address _anji) public onlyOwner {
        anji = _anji;
    }

    function setBUSDThreshold(uint256 _threshold) public onlyOwner {
        busdThreshold = _threshold;
    }

    function setFeeAddress(address _feeAddress) public onlyOwner {
        feeAddress = _feeAddress;
    }

    function setFeeOFF(bool _feeoff) public onlyOwner {
        feeOFF = true;
    }

    function _feeAmount(uint amount, address tokenIn) public returns (uint) {
        if (tokenIn == anji && feeOFF == true) {
            return 0;
        }

        uint feeAmount;
        uint256 balance = IERC20(anji).balanceOf(msg.sender);
        address[] memory path = new address[](3);
        path[0] = anji;
        path[1] = WETH;
        path[2] = BUSD;
        uint256[] memory amountsOut = PancakeLibrary.getAmountsOut(factory, balance, path);
        if (amountsOut[2] > busdThreshold) {
            feeAmount = 1;
        } else {
            feeAmount = 2;
        }
        
        uint fee = amount.mul(feeAmount)/1000;
        return fee;
    }

    function _transferFee(address token, uint fee) internal {
        if (fee > 0) {
            TransferHelper.safeTransferFrom(token, msg.sender, feeAddress, fee);
        }
    }

    // **** SWAP ****
    // requires the initial amount to have already been sent to the first pair
    function _swap(uint[] memory amounts, address[] memory path, address _to) internal virtual {
        for (uint i; i < path.length - 1; i++) {
            (address input, address output) = (path[i], path[i + 1]);
            (address token0,) = PancakeLibrary.sortTokens(input, output);
            uint amountOut = amounts[i + 1];
            (uint amount0Out, uint amount1Out) = input == token0 ? (uint(0), amountOut) : (amountOut, uint(0));
            address to = i < path.length - 2 ? PancakeLibrary.pairFor(factory, output, path[i + 2]) : _to;
            IPancakePair(PancakeLibrary.pairFor(factory, input, output)).swap(
                amount0Out, amount1Out, to, new bytes(0)
            );
        }
    }
    function swapExactTokensForTokens(
        uint amountIn,
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    ) external virtual override ensure(deadline) returns (uint[] memory amounts) {
        uint fee = _feeAmount(amountIn);
        uint amount = amountIn - fee;
        amounts = PancakeLibrary.getAmountsOut(factory, amount, path);
        require(amounts[amounts.length - 1] >= amountOutMin, 'AnjiRouter: INSUFFICIENT_OUTPUT_AMOUNT');
        TransferHelper.safeTransferFrom(
            path[0], msg.sender, PancakeLibrary.pairFor(factory, path[0], path[1]), amounts[0]
        );
        _swap(amounts, path, to);
        _transferFee(path[0], fee);
    }
    function swapTokensForExactTokens(
        uint amountOut,
        uint amountInMax,
        address[] calldata path,
        address to,
        uint deadline
    ) external virtual override ensure(deadline) returns (uint[] memory amounts) {
        amounts = PancakeLibrary.getAmountsIn(factory, amountOut, path);
        require(amounts[0] <= amountInMax, 'AnjiRouter: EXCESSIVE_INPUT_AMOUNT');
        TransferHelper.safeTransferFrom(
            path[0], msg.sender, PancakeLibrary.pairFor(factory, path[0], path[1]), amounts[0]
        );
        _swap(amounts, path, to);
        uint fee = _feeAmount(amounts[0]);
        _transferFee(path[0], fee);
    }
    function swapExactETHForTokens(uint amountOutMin, address[] calldata path, address to, uint deadline)
        external
        virtual
        override
        payable
        ensure(deadline)
        returns (uint[] memory amounts)
    {
        require(path[0] == WETH, 'AnjiRouter: INVALID_PATH');
        uint amountIn = msg.value;
        uint fee = _feeAmount(amountIn);
        uint amount = amountIn - fee;
        amounts = PancakeLibrary.getAmountsOut(factory, amount, path);
        require(amounts[amounts.length - 1] >= amountOutMin, 'AnjiRouter: INSUFFICIENT_OUTPUT_AMOUNT');
        IWETH(WETH).deposit{value: amounts[0]}();
        assert(IWETH(WETH).transfer(PancakeLibrary.pairFor(factory, path[0], path[1]), amounts[0]));
        _swap(amounts, path, to);
        if (fee > 0) {
            TransferHelper.safeTransferETH(feeAddress, fee);
        }
    }
    function swapTokensForExactETH(uint amountOut, uint amountInMax, address[] calldata path, address to, uint deadline)
        external
        virtual
        override
        ensure(deadline)
        returns (uint[] memory amounts)
    {
        require(path[path.length - 1] == WETH, 'AnjiRouter: INVALID_PATH');
        amounts = PancakeLibrary.getAmountsIn(factory, amountOut, path);
        require(amounts[0] <= amountInMax, 'AnjiRouter: EXCESSIVE_INPUT_AMOUNT');
        TransferHelper.safeTransferFrom(
            path[0], msg.sender, PancakeLibrary.pairFor(factory, path[0], path[1]), amounts[0]
        );
        _swap(amounts, path, address(this));
        IWETH(WETH).withdraw(amounts[amounts.length - 1]);
        TransferHelper.safeTransferETH(to, amounts[amounts.length - 1]);
        uint fee = _feeAmount(amounts[0]);
        _transferFee(path[0], fee);
    }
    function swapExactTokensForETH(uint amountIn, uint amountOutMin, address[] calldata path, address to, uint deadline)
        external
        virtual
        override
        ensure(deadline)
        returns (uint[] memory amounts)
    {
        require(path[path.length - 1] == WETH, 'AnjiRouter: INVALID_PATH');
        uint fee = _feeAmount(amountIn);
        uint amount = amountIn - fee;
        amounts = PancakeLibrary.getAmountsOut(factory, amount, path);
        require(amounts[amounts.length - 1] >= amountOutMin, 'AnjiRouter: INSUFFICIENT_OUTPUT_AMOUNT');
        TransferHelper.safeTransferFrom(
            path[0], msg.sender, PancakeLibrary.pairFor(factory, path[0], path[1]), amounts[0]
        );
        _swap(amounts, path, address(this));
        IWETH(WETH).withdraw(amounts[amounts.length - 1]);
        TransferHelper.safeTransferETH(to, amounts[amounts.length - 1]);
        _transferFee(path[0], fee);
    }
    function swapETHForExactTokens(uint amountOut, address[] calldata path, address to, uint deadline)
        external
        virtual
        override
        payable
        ensure(deadline)
        returns (uint[] memory amounts)
    {
        require(path[0] == WETH, 'AnjiRouter: INVALID_PATH');
        amounts = PancakeLibrary.getAmountsIn(factory, amountOut, path);
        require(amounts[0] <= msg.value, 'AnjiRouter: EXCESSIVE_INPUT_AMOUNT');
        IWETH(WETH).deposit{value: amounts[0]}();
        assert(IWETH(WETH).transfer(PancakeLibrary.pairFor(factory, path[0], path[1]), amounts[0]));
        _swap(amounts, path, to);
        // refund dust eth, if any
        uint fee = _feeAmount(amounts[0]);
        if (fee > 0) {
            TransferHelper.safeTransferETH(feeAddress, fee);
        }
        if (msg.value - fee > amounts[0]) TransferHelper.safeTransferETH(msg.sender, msg.value - amounts[0] - fee);
    }

    // **** SWAP (supporting fee-on-transfer tokens) ****
    // requires the initial amount to have already been sent to the first pair
    function _swapSupportingFeeOnTransferTokens(address[] memory path, address _to) internal virtual {
        for (uint i; i < path.length - 1; i++) {
            (address input, address output) = (path[i], path[i + 1]);
            (address token0,) = PancakeLibrary.sortTokens(input, output);
            IPancakePair pair = IPancakePair(PancakeLibrary.pairFor(factory, input, output));
            uint amountInput;
            uint amountOutput;
            { // scope to avoid stack too deep errors
            (uint reserve0, uint reserve1,) = pair.getReserves();
            (uint reserveInput, uint reserveOutput) = input == token0 ? (reserve0, reserve1) : (reserve1, reserve0);
            amountInput = IERC20(input).balanceOf(address(pair)).sub(reserveInput);
            amountOutput = PancakeLibrary.getAmountOut(amountInput, reserveInput, reserveOutput);
            }
            (uint amount0Out, uint amount1Out) = input == token0 ? (uint(0), amountOutput) : (amountOutput, uint(0));
            address to = i < path.length - 2 ? PancakeLibrary.pairFor(factory, output, path[i + 2]) : _to;
            pair.swap(amount0Out, amount1Out, to, new bytes(0));
        }
    }
    function swapExactTokensForTokensSupportingFeeOnTransferTokens(
        uint amountIn,
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    ) external virtual override ensure(deadline) {
        uint fee = _feeAmount(amountIn);
        uint amount = amountIn - fee;
        TransferHelper.safeTransferFrom(
            path[0], msg.sender, PancakeLibrary.pairFor(factory, path[0], path[1]), amount
        );
        uint balanceBefore = IERC20(path[path.length - 1]).balanceOf(to);
        _swapSupportingFeeOnTransferTokens(path, to);
        _transferFee(path[0], fee);
        require(
            IERC20(path[path.length - 1]).balanceOf(to).sub(balanceBefore) >= amountOutMin,
            'AnjiRouter: INSUFFICIENT_OUTPUT_AMOUNT'
        );
    }
    function swapExactETHForTokensSupportingFeeOnTransferTokens(
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    )
        external
        virtual
        override
        payable
        ensure(deadline)
    {
        require(path[0] == WETH, 'AnjiRouter: INVALID_PATH');
        uint amountIn = msg.value;
        uint fee = _feeAmount(amountIn);
        uint amount = amountIn - fee;
        IWETH(WETH).deposit{value: amount}();
        assert(IWETH(WETH).transfer(PancakeLibrary.pairFor(factory, path[0], path[1]), amount));
        uint balanceBefore = IERC20(path[path.length - 1]).balanceOf(to);
        _swapSupportingFeeOnTransferTokens(path, to);
        if (fee > 0) {
            TransferHelper.safeTransferETH(feeAddress, fee);
        }
        require(
            IERC20(path[path.length - 1]).balanceOf(to).sub(balanceBefore) >= amountOutMin,
            'AnjiRouter: INSUFFICIENT_OUTPUT_AMOUNT'
        );
    }
    function swapExactTokensForETHSupportingFeeOnTransferTokens(
        uint amountIn,
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    )
        external
        virtual
        override
        ensure(deadline)
    {
        require(path[path.length - 1] == WETH, 'AnjiRouter: INVALID_PATH');
        uint fee = _feeAmount(amountIn);
        uint amount = amountIn - fee;
        TransferHelper.safeTransferFrom(
            path[0], msg.sender, PancakeLibrary.pairFor(factory, path[0], path[1]), amount
        );
        _swapSupportingFeeOnTransferTokens(path, address(this));
        uint amountOut = IERC20(WETH).balanceOf(address(this));
        require(amountOut >= amountOutMin, 'AnjiRouter: INSUFFICIENT_OUTPUT_AMOUNT');
        IWETH(WETH).withdraw(amountOut);
        TransferHelper.safeTransferETH(to, amountOut);
        _transferFee(path[0], fee);
    }

    // **** LIBRARY FUNCTIONS ****
    function quote(uint amountA, uint reserveA, uint reserveB) public pure virtual override returns (uint amountB) {
        return PancakeLibrary.quote(amountA, reserveA, reserveB);
    }

    function getAmountOut(uint amountIn, uint reserveIn, uint reserveOut)
        public
        pure
        virtual
        override
        returns (uint amountOut)
    {
        return PancakeLibrary.getAmountOut(amountIn, reserveIn, reserveOut);
    }

    function getAmountIn(uint amountOut, uint reserveIn, uint reserveOut)
        public
        pure
        virtual
        override
        returns (uint amountIn)
    {
        return PancakeLibrary.getAmountIn(amountOut, reserveIn, reserveOut);
    }

    function getAmountsOut(uint amountIn, address[] memory path)
        public
        view
        virtual
        override
        returns (uint[] memory amounts)
    {
        return PancakeLibrary.getAmountsOut(factory, amountIn, path);
    }

    function getAmountsIn(uint amountOut, address[] memory path)
        public
        view
        virtual
        override
        returns (uint[] memory amounts)
    {
        return PancakeLibrary.getAmountsIn(factory, amountOut, path);
    }
}
