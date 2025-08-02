const std = @import("std");
const parser = @import("ast.zig");

const expect = std.testing.expect;
const expectEqual = std.testing.expectEqual;
const expectError = std.testing.expectError;

test "Casting test" {
    try expectEqual(@as(i64, @intFromFloat(89.1234)), 89);
    try expectEqual(@as(f64, @floatFromInt(123)), 123.00);

    const int: i64 = 12331310;
    var convertedFloat: f64 = @floatFromInt(int);
    _ = &convertedFloat;
    try expectEqual(convertedFloat, 12331310.00);

    const float: f64 = 123111231.92312;
    var convertedInt: i64 = @intFromFloat(float);
    _ = &convertedInt;
    try expectEqual(convertedInt, 123111231);
}

test "Node calc test" {
    const Node = parser.Node;
    const PEMDAS = parser.PEMDAS;

    const leftVal: i64 = 100;
    var leftNode = Node{
        .data = .{
            .value = .{ .INT = leftVal },
        },
    };

    const rightVal: f64 = 5.5;
    var rightNode = Node{
        .data = .{ .value = .{ .FLOAT = rightVal } },
    };

    var operator = PEMDAS.MULTIPLY;
    _ = &operator;
    var root = Node{ .data = .{ .value = .{ .OPERATOR = operator } }, .right = &rightNode, .left = &leftNode };

    var result = try root.calc();
    try expect(result.isDataType(.FLOAT));
    try expectEqual(try result.toFloat(), 550);
}

test "Node calc integer" {
    const Node = parser.Node;
    const PEMDAS = parser.PEMDAS;

    const leftVal: i64 = 100;
    var leftNode = Node{
        .data = .{
            .value = .{ .INT = leftVal },
        },
    };

    const rightVal: f64 = 5;
    var rightNode = Node{
        .data = .{ .value = .{ .INT = rightVal } },
    };

    var operator = PEMDAS.MULTIPLY;
    _ = &operator;
    var root = Node{ .data = .{ .value = .{ .OPERATOR = operator } }, .right = &rightNode, .left = &leftNode };

    var result = try root.calc();
    try expect(result.isDataType(.INT));
    try expectEqual(try result.toFloat(), 500);
}

test "Devide by zero error" {
    const Node = parser.Node;
    const PEMDAS = parser.PEMDAS;

    const leftVal: i64 = 100;
    var leftNode = Node{
        .data = .{
            .value = .{ .INT = leftVal },
        },
    };

    const rightVal: f64 = 0;
    var rightNode = Node{
        .data = .{ .value = .{ .FLOAT = rightVal } },
    };

    var operator = PEMDAS.DEVIDE;
    _ = &operator;
    var root = Node{ .data = .{ .value = .{ .OPERATOR = operator } }, .right = &rightNode, .left = &leftNode };

    try expectError(parser.ParseErrors.DevisionByZero, root.calc());
}

test "Parsing test" {
    const parse = parser.parse;
    {
        var nodeData = try parse("1 + 3");

        try expect(nodeData.value == .INT);
        try expectEqual(4, try nodeData.toInt());
    }

    {
        var nodeData = try parse("1 + 3.5");

        try expect(nodeData.value == .FLOAT);
        try expectEqual(4.5, try nodeData.toFloat());
    }

    {
        var nodeData = try parse("1 / 2");

        try expect(nodeData.value == .FLOAT);
        try expectEqual(0.5, try nodeData.toFloat());
    }

    {
        var nodeData = try parse("1 - 5 + 7 * 8 - 1");

        try expect(nodeData.value == .INT);
        try expectEqual(51, try nodeData.toInt());
    }

    {
        var nodeData = try parse("7 * 2 - 8 * 3 + 2 * 2");

        try expect(nodeData.value == .INT);
        try expectEqual(-6, try nodeData.toInt());
    }
}
