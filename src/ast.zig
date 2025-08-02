const std = @import("std");

const allocator = std.heap.page_allocator;
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

/// Operators used to make mathematical equations ordered hierarchically.
pub const PEMDAS = enum(u8) {
    PARENTHESIS = 0,
    EXPONENT = 1,
    MULTIPLY = 3,
    DEVIDE = 2,
    ADDITION = 5,
    SUBTRACTION = 4,

    pub fn fromChar(token: u8) ParseErrors!PEMDAS {
        return switch (token) {
            '+' => PEMDAS.ADDITION,
            '-' => PEMDAS.SUBTRACTION,
            '*' => PEMDAS.MULTIPLY,
            '/' => PEMDAS.DEVIDE,
            '^' => PEMDAS.EXPONENT,
            '(', ')' => PEMDAS.PARENTHESIS,
            else => return ParseErrors.InvalidOperator
        };
    }

    pub fn toChar(token: PEMDAS) u8 {
        return switch (token) {
            .MULTIPLY => '*',
            .DEVIDE => '/',
            .ADDITION => '+',
            .SUBTRACTION => '-',
            .EXPONENT => '^',
            .PARENTHESIS => '|',
        };
    }

    fn int(this: PEMDAS) u8 {
        return @intFromEnum(this);
    }
};

const DataOptions = enum { INT, FLOAT, OPERATOR };

pub const DataTypes = union(DataOptions) {
    INT: i64,
    FLOAT: f64,
    OPERATOR: PEMDAS,

    fn toFloat(this: DataTypes) ParseErrors!f64 {
        return switch (this) {
            .INT => |int| @floatFromInt(int),
            .FLOAT => |float| float,
            .OPERATOR => ParseErrors.InvalidCast,
        };
    }
    
    fn toInt(this: DataTypes) ParseErrors!i64 {
        return switch (this) {
            .INT => |int| int,
            .FLOAT => |float| @intFromFloat(float),
            .OPERATOR => ParseErrors.InvalidCast,
        };
    }

    pub fn isDataType(this: DataTypes, types: DataOptions) bool {
        return this == types;
    }
};

pub const NodeData = struct {
    value: DataTypes,

    pub fn toFloat(this: *NodeData) ParseErrors!f64 {
        return this.value.toFloat();
    }

    pub fn toInt(this: *NodeData) ParseErrors!i64 {
        return this.value.toInt();
    }
};

pub const Node = struct {
    data: NodeData,
    left: ?*Node = null,
    right: ?*Node = null,

    fn newNode(value: DataTypes) !*Node {
        var node = try allocator.create(Node);
        _ = &node;
        node.* = Node{
            .data = .{
                .value = value
            }
        };

        return node;
    }

    fn deinit(this: *Node) void {
        if (this.left) |left| {
            left.deinit();
            allocator.destroy(left);
        }
        if (this.right) |right| {
            right.deinit();
            allocator.destroy(right);
        }
    }

    /// Operator to int
    fn operToInt(this: *Node) u8 {
        return this.data.value.OPERATOR.int();
    }

    // It will be handled as float as it doesn't causes any loosie convertion as int to
    // float does
    fn calcData(this: *Node) ParseErrors!DataTypes {
        if (this.data.value == .OPERATOR) {
            const data = try this.calc();
            return data.value;
        }
        return this.data.value;
    }

    pub fn calc(this: *Node) !NodeData {
        if (this.data.value.isDataType(.OPERATOR)) { 
            var left: *Node = this.left orelse return ParseErrors.IncompletEquation;
            var right: *Node = this.right orelse return ParseErrors.IncompletEquation;

            const leftResultType = try left.calcData();
            const rightResultType = try right.calcData();

            var resultType: DataOptions = .INT;
            if (leftResultType.isDataType(.FLOAT) or rightResultType.isDataType(.FLOAT)) {
                resultType = .FLOAT;
            }

            const leftResult = try leftResultType.toFloat();
            const rightResult = try rightResultType.toFloat();

            var result: f64 = switch (this.data.value.OPERATOR) {
                .ADDITION => leftResult + rightResult,
                .SUBTRACTION => leftResult - rightResult,
                .MULTIPLY => leftResult * rightResult,
                .DEVIDE => blk: {
                    if (rightResult == 0) 
                        return ParseErrors.DevisionByZero;

                    resultType = .FLOAT;
                    break :blk leftResult / rightResult;
                },
                else => return ParseErrors.UnhandledOperation,
            };
            _ = &result;

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

    fn printEquation(this: *Node) !void {
        if (this.left) |left|
            try left.printEquation();

        switch (this.data.value) {
            .INT => print("{d} ", .{ try this.data.toInt() }),
            .FLOAT => print("{d:.2} ", .{ try this.data.toFloat() }),
            .OPERATOR => |operation| print("{c} ", .{ operation.toChar() })
        }

        if (this.right) |right|
            try right.printEquation();
    }
};

fn deinitRoot(root: *Node) void {
    root.deinit();
    allocator.destroy(root);
}

fn parseDataType(str: []const u8) !DataTypes {
    if ((str.len == 1) and (!std.ascii.isDigit(str[0]))) {
        var operator = try PEMDAS.fromChar(str[0]);
        _ = &operator;
        return DataTypes{
            .OPERATOR = operator
        };
    }

    if (parseInt(i64, str, 10)) |int| {
        return DataTypes{
            .INT = int
        };
    } else |_| {
        if (parseFloat(f64, str)) |float| {
            return DataTypes{
                .FLOAT = float,
            };
        } else |_| {}
        return ParseErrors.InvalidNumericValue;
    }
}

pub fn parse(str: []const u8) !NodeData {
    var tokens = std.mem.tokenizeAny(u8, str, " \n\t\r");

    if (tokens.peek() == null) 
        return ParseErrors.IncompletEquation;

    const rootVal = tokens.next().?;
    var root = try Node.newNode(try parseDataType(rootVal));
    defer deinitRoot(root);
    // last APPENDED note!
    var bufferNode = root;

    while (tokens.next()) |operatorVal| {
        if (tokens.next()) |numericVal| {
            const numericNode = try Node.newNode(try parseDataType(numericVal));
            var operatorNode = try Node.newNode(try parseDataType(operatorVal));
            operatorNode.right = numericNode;

            if (root.data.value != .OPERATOR) {
                operatorNode.left = root;
                root = operatorNode;
                bufferNode = root;
                continue;
            }

            const bufferInt = bufferNode.operToInt();
            const rootInt = root.operToInt();
            if (bufferInt > operatorNode.operToInt()) {
                operatorNode.left = bufferNode.right;
                bufferNode.right = operatorNode;

                continue;
            } else if (rootInt > operatorNode.operToInt()) {
                operatorNode.left = root.right;
                root.right = operatorNode;

                continue; 
            } else {
                operatorNode.left = root;
                root = operatorNode;
                bufferNode = root;
                continue;
            }

            continue;
        }
        return ParseErrors.IncompletEquation;
    }

    print("\n", .{});
    try root.printEquation();
    print("\n", .{});
    return try root.calc();
}
