const std = @import("std");
const Int = std.meta.Int;
const unsigned = std.builtin.Signedness.unsigned;

pub fn main() void {
    // A sample integer to pull bits from:
    var bits: u64 = 0x01234567890123456;

    // Pull each 16 bit subsection of the u64 as a test.
    std.debug.print("0x{X}\n", .{extractBits(bits, 0, 16)});
    std.debug.print("0x{X}\n", .{extractBits(bits, 16, 16)});
    std.debug.print("0x{X}\n", .{extractBits(bits, 32, 16)});
    std.debug.print("0x{X}\n", .{extractBits(bits, 48, 16)});
}

// ctz cannot be used within a function signature as it doesn't accept comptime_int.
// Therefore, we split it out into this function to give an explicit size.
// Perhaps @ctz(@as(u64, @bitSizeOf(@TypeOf(bits)))) would also work...
pub fn BitIndexType(comptime BaseType: type) type {
    const base_type_size_bytes: u64 = @bitSizeOf(BaseType);
    const trailing_zeros: u64 = @ctz(base_type_size_bytes);
    return Int(unsigned, trailing_zeros);
}

// Extract a number of bits from a bit offset from a given integer.
// The setEvalBranchQuota is set to allow generation for up to 64 bit
// integers.
// This is likely very wasteful, generating a lot of code at a call site, although
// I haven't done any measurements to see how it effect compilation time..
pub fn extractBits(bits: anytype, bit_offset: BitIndexType(@TypeOf(bits)), field_width_bits: BitIndexType(@TypeOf(bits))) u64 {
    @setEvalBranchQuota(64 * 64 * 2);

    const size = @sizeOf(@TypeOf(bits));
    switch (field_width_bits) {
        inline else => |field_width| {
            switch (bit_offset) {
                inline else => |offset| {
                    const IntType = std.meta.Int(std.builtin.Signedness.unsigned, field_width);
                    var ptr: *align(size:offset:size) const IntType = @ptrCast(*align(size:offset:size) const IntType, &bits);
                    return @intCast(u64, ptr.*);
                },
            }
        },
    }
}
