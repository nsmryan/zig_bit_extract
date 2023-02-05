const std = @import("std");
const Int = std.meta.Int;
const unsigned = std.builtin.Signedness.unsigned;

pub fn main() void {
    // A sample integer to pull bits from:
    var bits: u64 = 0x0123456789012345;

    // Pull each 16 bit subsection of the u64 as a test.
    std.debug.print("0x{X}\n", .{extractBits(bits, 0, 16)});
    std.debug.print("0x{X}\n", .{extractBits(bits, 16, 16)});
    std.debug.print("0x{X}\n", .{extractBits(bits, 32, 16)});
    std.debug.print("0x{X}\n", .{extractBits(bits, 48, 16)});

    // Surprisingly this works, but seems to get 0s for missing bits...
    // Instead it results in '0x01', which is the high byte.
    std.debug.print("0x{X}\n", .{extractBits(bits, 56, 16)});
    // Equivalent to:
    std.debug.print("0x{X}\n", .{(bits >> 56) & 0xFFFFFFFF});

    // Crashes with a compile error message about needing a power of 2 byte size.
    //var bits_u3: u3 = 1;
    //std.debug.print("0x{X}\n", .{extractBits(bits_u3, 0, 1)});

    // Pull each 16 bit subsection of the u64 as a test of the simplier version.
    std.debug.print("0x{X}\n", .{extractBitsSimple(bits, 0, 16)});
    std.debug.print("0x{X}\n", .{extractBitsSimple(bits, 16, 16)});
    std.debug.print("0x{X}\n", .{extractBitsSimple(bits, 32, 16)});
    std.debug.print("0x{X}\n", .{extractBitsSimple(bits, 48, 16)});
    std.debug.print("0x{X}\n", .{extractBitsSimple(bits, 48, 16)});

    // Try with u32 to show that this works on other integer types, while the simpler
    // version does not.
    var bits_u32: u32 = 0x01234567;
    // This does not compile because the extractBitsSimple version generates
    // branchs for u6 possibilities and notices that the given u32 does not work
    // with some of these branchs.
    //std.debug.print("0x{X}\n", .{extractBitsSimple(bits_u32, 10, 16)});
    std.debug.print("0x{X}\n", .{extractBits(bits_u32, 10, 16)});
}

// ctz cannot be used within a function signature as it doesn't accept comptime_int.
// Therefore, we split it out into this function to give an explicit size.
// Perhaps @ctz(@as(u64, @bitSizeOf(@TypeOf(bits)))) would also work...
pub fn BitIndexType(comptime BaseType: type) type {
    const base_type_size_bytes: u64 = @bitSizeOf(BaseType);
    if (@popCount(base_type_size_bytes) != 1) {
        @compileError("extractBits cannot handle integer sizes that are not powers of 2!");
    }
    const trailing_zeros: u64 = @ctz(base_type_size_bytes);
    return Int(unsigned, trailing_zeros);
}

// Extract a number of bits from a bit offset from a given integer.
// The setEvalBranchQuota is set to allow generation for up to 64 bit
// integers.
// This is likely very wasteful, generating a lot of code at a call site, although
// I haven't done any measurements to see how it effect compilation time..
pub fn extractBits(bits: anytype, bit_offset: BitIndexType(@TypeOf(bits)), field_width_bits: BitIndexType(@TypeOf(bits))) u64 {
    // I'm actually not sure why this is the right number, but this is how many branches are generated.
    @setEvalBranchQuota(2 << 12);

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

// This is would be the better version of this function, but it doesn't work on small 'bits' types.
// The pointer casts in some of the generated branchs fail at compile time on smaller integer types then u64
// because they represent offsets outside of the valid range even if the user never hit those branches in a
// particular callsite. This is a problem with moving data into comptime- it must account for all possible
// dynamic values.
pub fn extractBitsSimple(bits: anytype, bit_offset: u6, field_width_bits: u6) u64 {
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
