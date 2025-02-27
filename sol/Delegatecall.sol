// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract DelegateCallTest {
    bool public testResult;
    uint256 public testCounter; // 用于内存隔离测试

    // 主测试入口
    function run() external returns (uint256) {
        initializeTests();
        return testResult ? 1 : 0;
    }

    function initializeTests() public {
        testResult = true;
        
        testResult = testResult && testBasicDelegateCall();
        testResult = testResult && testStorageLayoutConflict();
        testResult = testResult && testContextPreservation();
        testResult = testResult && testReturnValuePropagation();
        testResult = testResult && testFailedDelegateCall();
        testResult = testResult && testNonExistingContract();
        testResult = testResult && testNestedDelegateCalls();
        testResult = testResult && testStateRollback();
        testResult = testResult && testDifferentDataTypes();
        testResult = testResult && testGasForwarding();
        // testResult = testResult && testValueTransfer();
        testResult = testResult && testMemoryIsolation();
    }

    // 测试1：基础委托调用功能
    function testBasicDelegateCall() public returns (bool) {
        DelegateTarget target = new DelegateTarget();
        (bool success, ) = address(target).delegatecall(
            abi.encodeWithSignature("updateStorage(uint256)", 42)
        );
        return success && (DelegateTarget(address(this)).getValue() == 42);
    }

    // 测试2：存储布局冲突测试
    function testStorageLayoutConflict() public returns (bool) {
        StorageConflict target = new StorageConflict();
        (bool success, ) = address(target).delegatecall(
            abi.encodeWithSignature("updateConflictingStorage(uint256)", 100)
        );
        return success && (StorageConflict(address(this)).conflictingSlot() == 100);
    }

    // 测试3：上下文保留（sender/value）
    function testContextPreservation() public payable returns (bool) {
        ContextChecker target = new ContextChecker();
        (bool success, bytes memory data) = address(target).delegatecall(
            abi.encodeWithSignature("getContext()")
        );
        (address sender, uint256 value) = abi.decode(data, (address, uint256));
        return success && (sender == address(this)) && (value == 0 ether);
    }

    // 测试4：返回值传播
    function testReturnValuePropagation() public returns (bool) {
        ReturnTarget target = new ReturnTarget();
        (, bytes memory data) = address(target).delegatecall(
            abi.encodeWithSignature("getData()")
        );
        return keccak256(data) == keccak256(abi.encodePacked("test data"));
    }

    // 测试5：失败委托调用（应返回false）
    function testFailedDelegateCall() public returns (bool) {
        RevertTarget target = new RevertTarget();
        (bool success, ) = address(target).delegatecall(
            abi.encodeWithSignature("forceRevert()")
        );
        return !success;
    }

    // 测试6：调用不存在合约
    function testNonExistingContract() public returns (bool) {
        address fakeAddr = address(0x1234);
        (bool success, ) = fakeAddr.delegatecall(
            abi.encodeWithSignature("fakeFunction()")
        );
        return !success;
    }

    // 测试7：嵌套委托调用
    function testNestedDelegateCalls() public returns (bool) {
        NestedDelegateCaller target = new NestedDelegateCaller();
        (bool success, ) = address(target).delegatecall(
            abi.encodeWithSignature("executeNestedCall()")
        );
        return success && (NestedDelegateCaller(address(this)).getDepth() == 2);
    }

    // 测试8：状态回滚测试
    function testStateRollback() public returns (bool) {
        StateRollbackTarget target = new StateRollbackTarget();
        uint256 originalValue = StateRollbackTarget(address(this)).rollbackValue();
        
        (bool success, ) = address(target).delegatecall(
            abi.encodeWithSignature("updateWithRollback()")
        );
        
        uint256 newValue = StateRollbackTarget(address(this)).rollbackValue();
        return !success && (newValue == originalValue);
    }

    // 测试9：多数据类型兼容性
    function testDifferentDataTypes() public returns (bool) {
        DataTypesTarget target = new DataTypesTarget();
        (bool success, ) = address(target).delegatecall(
            abi.encodeWithSignature("handleDataTypes(uint256,bool,address)", 
            12345, true, address(0x5678))
        );
        DataTypesTarget.Data memory data = DataTypesTarget(address(this)).getStructData();
        return success && (data.num == 12345) && data.flag && (data.addr == address(0x5678));
    }

    // 测试10：Gas转发验证
    function testGasForwarding() public returns (bool) {
        GasConsumer target = new GasConsumer();
        uint256 gasLimit = 500000;
        
        uint256 startGas = gasleft();
        (bool success, ) = address(target).delegatecall{gas: gasLimit}(
            abi.encodeWithSignature("consumeGas()")
        );
        uint256 gasUsed = startGas - gasleft();
        
        return success && (gasUsed > gasLimit * 90 / 100); // 消耗至少90%的gas
    }

    // // 测试11：转账功能测试
    // function testValueTransfer() public returns (bool) {
    //     ValueReceiver target = new ValueReceiver();
    //     uint256 sendAmount = 1 ether;
        
    //     (bool success, bytes memory data) = address(target).delegatecall{value: sendAmount}(
    //         abi.encodeWithSignature("receiveFunds()")
    //     );
    //     uint256 received = abi.decode(data, (uint256));
    //     return success && (received == sendAmount);
    // }

    // 测试12：内存隔离验证
    function testMemoryIsolation() public returns (bool) {
        MemoryTester target = new MemoryTester();
        testCounter = 100;
        
        (bool success, ) = address(target).delegatecall(
            abi.encodeWithSignature("modifyMemory()")
        );
        return success && (testCounter == 100); // 调用不应影响调用者内存
    }


    // 允许接收ETH
    receive() external payable {}
}


    // 辅助合约定义
    contract DelegateTarget {
        uint256 public value;
        function getValue() public view returns (uint256) { return value; }
        function updateStorage(uint256 _v) public { value = _v; }
    }

    contract StorageConflict {  
        uint256 public conflictingSlot;
        function getConflictingSlot() public view returns (uint256) { return conflictingSlot; }
        function updateConflictingStorage(uint256 _v) public { conflictingSlot = _v; }
    }

    contract ContextChecker {
        function getContext() public payable returns (address, uint256) {
            return (msg.sender, msg.value);
        }
    }

    contract ReturnTarget {
        function getData() public pure returns (bytes memory) {
            return abi.encodePacked("test data");
        }
    }

    contract RevertTarget {
        function forceRevert() public pure {
            revert("forced revert");
        }
    }

    contract NestedDelegateCaller {
        uint256 public callDepth;
        
        function executeNestedCall() public {
            (bool success, ) = address(this).delegatecall(
                abi.encodeWithSignature("innerCall()")
            );
            require(success, "Nested call failed");
        }
        
        function innerCall() public {
            callDepth++;
        }
        
        function getDepth() public view returns (uint256) {
            return callDepth;
        }
    }

    contract StateRollbackTarget {
        uint256 public rollbackValue;
        
        function updateWithRollback() public {
            rollbackValue = 999;
            revert("rollback test");
        }
    }

    contract DataTypesTarget {
        struct Data {
            uint256 num;
            bool flag;
            address addr;
        }
        Data public storedData;
        
        function handleDataTypes(uint256 n, bool b, address a) public {
            storedData = Data(n, b, a);
        }
        
        function getStructData() public view returns (Data memory) {
            return storedData;
        }
    }

    contract GasConsumer {
        uint256[] public dummyArray;
        
        function consumeGas() public {
            for(uint256 i = 0; i < 100; i++) {
                dummyArray.push(i);
            }
        }
    }

    contract ValueReceiver {
        function receiveFunds() public payable returns (uint256) {
            return msg.value;
        }
    }

    contract MemoryTester {
        function modifyMemory() public pure {
            bytes memory temp = new bytes(64);
            assembly {
                mstore(temp, 0x12345678)
            }
        }
    }