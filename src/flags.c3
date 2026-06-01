module tiny_vm::flags;

import std::collections::map;

struct FlagEntry {
    any ptr;
    bool has_arg;
}

struct FlagTbl {
    HashMap{String, FlagEntry} tbl;
}

fn String[] shift_args(String[] args, int shift_by = 1) {
    if (args.len > shift_by) {
        return args[shift_by..];
    } else {
        return args[..];
    }
}

fn void FlagTbl.reg_data_flag(&self, String opt, any ptr, any ptr) {
    self.tbl.set(opt, (FlagEntry){ .ptr = ptr, .has_arg = false });
}

fn void FlagTbl.reg_bool_flag(&self, String opt, bool* ptr) {
    self.tbl.set(opt, (FlagEntry){ .ptr = ptr, .has_arg = true });
}

fn void FlagTbl.parse_flags(&self, String[] args) {
    String[] cur_args;
    if (args.len )
    while (cur_args.len > 1) {
        cur_args = shift_args(args);
        self.tbl.get(cur_args[]);
    }
}
