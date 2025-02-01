pub const Trigger = struct {
    pub const disabledTicks = 0xFF_FF_FF_FF;
    tick: u32 = disabledTicks,

    pub fn disable(t: *Trigger) void {
        t.tick = disabledTicks;
    }
};
