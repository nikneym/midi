const std = @import("std");
const os = std.os;
const mem = std.mem;

const MAX_MIDI_MSG_SIZE: usize = 3;

const REF_NOTE_NUMBER: usize = 69;
const REF_NOTE_FREQ: f64 = 440.0;

const Device = @This();
fd: os.fd_t,

pub fn initFd(fd: os.fd_t) Device {
    return .{ .fd = fd };
}

pub fn deinit(device: *Device) void {
    os.close(device.fd);
    device.* = undefined;
}

/// Returns if note has down.
inline fn isNoteOn(b: u8) bool {
    return b & (1 << 4) != 0 and b & (1 << 6) == 0;
}

/// Returns if note has pulled.
inline fn isNoteOff(b: u8) bool {
    return b & (1 << 4) == 0 and b & (1 << 6) != 0;
}

/// Gets the last 7 bits of an u8 and creates valid u7 integer from it.
inline fn getLast7(b: u8) u7 {
    return @truncate(b & 0x7F);
}

/// Gets the last 4 bits of an u8 and creates valid u4 integer from it.
inline fn getLast4(b: u8) u4 {
    return @truncate(b & 0x4F);
}

pub const Nuance = enum {
    pppp,
    ppp,
    pp,
    p,
    mp,
    mf,
    f,
    ff,
    fff,
    ffff,
};

/// flat representation is omitted
pub const Note = enum(u4) {
    C,
    Csharp,
    D,
    Dsharp,
    E,
    F,
    Fsharp,
    G,
    Gsharp,
    A,
    Asharp,
    B,
};

pub const KeyStatus = enum(u1) { off, on };

/// Represents a single MIDI packet that's coming from the device.
pub const Packet = packed struct {
    status: KeyStatus, // u1
    channel: u4, // u4
    note: Note, // u4
    octave: u4, // u4
    velocity: u7, // u7

    pub fn getNuance(p: Packet) Nuance {
        return switch (p.velocity) {
            0 => unreachable,
            1...8 => .pppp,
            9...20 => .ppp,
            21...31 => .pp,
            32...42 => .p,
            43...53 => .mp,
            54...64 => .mf,
            65...80 => .f,
            81...96 => .ff,
            97...112 => .fff,
            113...127 => .ffff,
        };
    }

    pub fn getFreq(p: Packet) f64 {
        const note_float: f64 = @floatFromInt(@as(usize, @intCast(p.octave)) * 12 + @as(usize, @intFromEnum(p.note)));

        return std.math.pow(f64, 2, (note_float - REF_NOTE_NUMBER) / 12.0) * REF_NOTE_FREQ;
    }
};

/// Gets the next message from the MIDI stream.
pub fn nextPacket(device: *Device) !Packet {
    var buf: [MAX_MIDI_MSG_SIZE]u8 = undefined;

    const len = try os.read(device.fd, &buf);
    _ = len;

    const chan = getLast4(buf[0]);

    //get which note is pressed
    const pitch = getLast7(buf[1]);
    // get velocity
    const velocity = getLast7(buf[2]);

    return Packet{
        .status = @enumFromInt(@intFromBool(isNoteOn(buf[0]))),
        .channel = chan,
        .note = @enumFromInt(@as(u4, @truncate(pitch % 12))),
        .octave = @truncate(pitch / 12),
        .velocity = velocity,
    };
}
