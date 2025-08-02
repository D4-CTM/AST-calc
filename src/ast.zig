const std = @import("std");

const parseFloat = std.fmt.parseFloat;
const parseInt = std.fmt.parseInt;
const isDigit = std.ascii.isDigit;
const print = std.debug.print;

pub const ParseErrors = error{
    InvalidOperator,
    InvalidNumericValue,
    UnhandledOperation,
    IncompletEquation,
    DevisionByZero,
    InvalidCast,
};

const char: type = u8;

/// Operators used to make mathematical equations ordered hierarchically.
pub const PEMDAS = enum(u8) {
    PARENTHESIS = 0,
    EXPONENT = 1,
    MULTIPLY = 2,
    DEVIDE = 3,
    ADDITION = 4,
    SUBTRACTION = 5,

    pub fn fromChar(token: char) PEMDAS {
        return switch (token) {
            '+' => PEMDAS.ADDITION,
            '-' => PEMDAS.SUBTRACTION,
            '*' => PEMDAS.MULTIPLY,
            '/' => PEMDAS.DEVIDE,
            '^' => PEMDAS.EXPONENT,
            '(', ')' => PEMDAS.PARENTHESIS,
        };
    }
};

const DataOptions = enum { INT, FLOAT, OPERATOR };

pub const DataTypes = union(DataOptions) {
    INT: i64,
    FLOAT: f64,
    OPERATOR: *PEMDAS,
};

pub const NodeData = struct {
    value: DataTypes,

    pub fn toFloat(this: *NodeData) ParseErrors!f64 {
        return switch (this.value) {
            .INT => |int| @floatFromInt(int),
            .FLOAT => |float| float,
            .OPERATOR => ParseErrors.InvalidCast,
        };
    }

    pub fn toInt(this: *NodeData) ParseErrors!i64 {
        return switch (this.value) {
            .INT => |int| int,
            .FLOAT => |float| @intFromFloat(float),
            .OPERATOR => ParseErrors.InvalidCast,
        };
    }

    pub fn isDataType(this: *NodeData, types: DataOptions) bool {
        return this.value == types;
    }
};

pub const Node = struct {
    data: NodeData,
    left: ?*Node = null,
    right: ?*Node = null,

    // It will be handled as float as it doesn't causes any loosie convertion as int to
    // float does
    fn calcData(this: *Node) ParseErrors!f64 {
        return this.data.toFloat() catch {
            var data = try this.calc();
            return try data.toFloat();
        };
    }

    pub fn calc(this: *Node) !NodeData {
        if (this.data.isDataType(.OPERATOR)) { 
            var left: *Node = this.left orelse return ParseErrors.IncompletEquation;
            var right: *Node = this.right orelse return ParseErrors.IncompletEquation;

            const leftResult = try left.calcData();
            const rightResult = try right.calcData();

            var result: f64 = switch (this.data.value.OPERATOR.*) {
                .ADDITION => leftResult + rightResult,
                .SUBTRACTION => leftResult - rightResult,
                .MULTIPLY => leftResult * rightResult,
                .DEVIDE => blk: {
                    if (rightResult == 0) 
                        return ParseErrors.DevisionByZero;

                    break :blk leftResult / rightResult;
                },
                else => return ParseErrors.UnhandledOperation,
            };
            _ = &result;

            var resultType: DataOptions = .INT;
            if (left.data.isDataType(.FLOAT) or right.data.isDataType(.FLOAT)) {
                resultType = .FLOAT;
            }

            const value: DataTypes = switch (resultType) {
                .INT => DataTypes{ .INT = @intFromFloat(result) },
                .FLOAT => DataTypes{ .FLOAT = result },
                else => return ParseErrors.InvalidCast,
            };

            return NodeData{
                .value = value,
            };
        }
        return this.data;
    }
};
