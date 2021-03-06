_EXPS = {
    calls = {}      -- { _printf=true, _myf=true, ... }
}

function check_lval (e1)
    return e1.lval and e1.fst
end
function check_depth (e1, e2)
    local ptr = _C.deref(e2.tp)
    return (not ptr) or (not e2.fst) or
            e1.fst.var.blk.depth >= e2.fst.var.blk.depth
end

F = {
    SetExp = function (me)
        local e1, e2 = unpack(me)
        ASR( check_lval(e1) and
             _C.contains(e1.tp,e2.tp) and
             check_depth(e1, e2),
                me, 'invalid attribution')
        e1.fst.se = 'wr'
    end,

    SetStmt = function (me)
        local e1, stmt = unpack(me)
        local evt = stmt[1].evt
        ASR(check_lval(e1), me, 'invalid attribution')
        e1.fst.se = 'wr'
        stmt.toset = e1
        if stmt.id == 'AwaitT' then
            ASR(_C.isNumeric(e1.tp), me, 'invalid attribution')
        else --'AwaitE'
            ASR( _C.contains(e1.tp,evt.tp) and
                 check_depth(e1,evt),
                    me, 'invalid attribution')
        end
    end,

    SetBlock = function (me)
        local e1, _ = unpack(me)
        ASR(check_lval(e1), me, 'invalid attribution')
        e1.fst.se = 'wr'
    end,
    Return = function (me)
        local e1 = _ITER'SetBlock'()[1]
        local e2 = unpack(me)
        ASR( _C.contains(e1.tp,e2.tp) and
             check_depth(e1, e2),
                me, 'invalid return value')
    end,

    AwaitE = function (me)
        local acc = unpack(me)
        if acc.evt.dir == 'internal' then
            acc.se = 'aw'
        end
    end,

    EmitE = function (me)
        local acc, exp = unpack(me)
        ASR((not exp) or _C.contains(acc.evt.tp,exp.tp), me, 'invalid emit')
        if acc.evt.dir == 'internal' then
            acc.se = 'tr'
        end
    end,

    CallStmt = function (me)
        local call = unpack(me)
        ASR(call.id == 'Op2_call', me, 'invalid statement')
    end,

-------------------------------------------------------------------------------

    Op2_call = function (me)
        local _, f, exps = unpack(me)
        me.tp = 'C'
        local ps = {}
        for i, exp in ipairs(exps) do
            ps[i] = exp.val
        end
        me.fst = nil
        me.val = f.val..'('..table.concat(ps,',')..')'
        me.fid = (f.id=='Cid' and f[1]) or '$anon'
        _EXPS.calls[me.fid] = true
    end,

    Op2_idx = function (me)
        local _, arr, idx = unpack(me)
        local _arr = ASR(_C.deref(arr.tp), me, 'cannot index a non array')
        ASR(_arr and _C.isNumeric(idx.tp), me, 'invalid array index')
        me.fst  = arr.fst
        me.tp   = _arr
        me.val  = '('..arr.val..'['..idx.val..'])'
        me.lval = true
    end,

    Op2_int_int = function (me)
        local op, e1, e2 = unpack(me)
        me.fst = nil
        me.tp  = 'int'
        me.val = '('..e1.val..op..e2.val..')'
        ASR(_C.isNumeric(e1.tp) and _C.isNumeric(e2.tp),
            me, 'invalid operands to binary "'..op..'"')
    end,
    ['Op2_-']  = 'Op2_int_int',
    ['Op2_+']  = 'Op2_int_int',
    ['Op2_%']  = 'Op2_int_int',
    ['Op2_*']  = 'Op2_int_int',
    ['Op2_/']  = 'Op2_int_int',
    ['Op2_|']  = 'Op2_int_int',
    ['Op2_&']  = 'Op2_int_int',
    ['Op2_<<'] = 'Op2_int_int',
    ['Op2_>>'] = 'Op2_int_int',
    ['Op2_^']  = 'Op2_int_int',

    Op1_int = function (me)
        local op, e1 = unpack(me)
        me.fst = nil
        me.tp  = 'int'
        me.val = '('..op..e1.val..')'
        ASR(_C.isNumeric(e1.tp), me, 'invalid operand to unary "'..op..'"')
    end,
    ['Op1_~']  = 'Op1_int',
    ['Op1_-']  = 'Op1_int',


    Op2_same = function (me)
        local op, e1, e2 = unpack(me)
        me.fst = nil
        me.tp  = 'int'
        me.val = '('..e1.val..op..e2.val..')'
        ASR(_C.max(e1.tp,e2.tp), me, 'invalid operands to binary "'..op..'"')
    end,
    ['Op2_=='] = 'Op2_same',
    ['Op2_!='] = 'Op2_same',
    ['Op2_>='] = 'Op2_same',
    ['Op2_<='] = 'Op2_same',
    ['Op2_>']  = 'Op2_same',
    ['Op2_<']  = 'Op2_same',


    Op2_any = function (me)
        local op, e1, e2 = unpack(me)
        me.fst = nil
        me.tp  = 'int'
        me.val = '('..e1.val..op..e2.val..')'
    end,
    ['Op2_||'] = 'Op2_any',
    ['Op2_&&'] = 'Op2_any',

    Op1_any = function (me)
        local op, e1 = unpack(me)
        me.fst = nil
        me.tp  = 'int'
        me.val = '('..op..e1.val..')'
    end,
    ['Op1_!']  = 'Op1_any',


    ['Op1_*'] = function (me)
        local op, e1 = unpack(me)
        me.fst  = e1.fst
        me.tp   = _C.deref(e1.tp)
        me.val  = '('..op..e1.val..')'
        me.lval = true
        ASR(me.tp, me, 'invalid operand to unary "*"')
    end,
    ['Op1_&'] = function (me)
        local op, e1 = unpack(me)
        ASR(check_lval(e1), me, 'invalid operand to unary "&"')
        me.fst = e1.fst
        me.fst.ref = true
        me.fst.se = 'no'   -- just getting the address
        me.tp  = e1.tp..'*'
        me.val = '('..op..e1.val..')'
        me.lval = false
    end,

    ['Op2_.'] = function (me)
        local op, e1, id = unpack(me)
        me.fst  = e1.fst
        me.tp   = 'C'
        me.val  = '('..e1.val..op..id..')'
        me.lval = true
    end,

    Op2_cast = function (me)
        local _, tp, exp = unpack(me)
        me.fst  = exp.fst
        me.tp   = tp
        me.val  = '(('..tp..')'..exp.val..')'
        me.lval = exp.lval
    end,

    Var = function (me)
        me.fst  = me
        me.tp   = me.var.tp
        me.lval = not me.var.arr    -- not .lval but has .fst
        me.se   = 'rd'
        me.val  = _ENV.reg(me.var)
    end,

    TIME = function (me)
        local h,m,s,ms = unpack(me)
        me.tp   = 'int'
        me.val  = ms + s*1000 + m*60000 + h*3600000
        me.lval = false
        ASR(me.val > 0, me,'must be >0')
    end,

    Cid = function (me)
        me.tp   = 'C'
        me.val  = string.sub(me[1], 2)
        me.lval = false
    end,

    SIZEOF = function (me)
        me.tp   = 'int'
        me.val  = 'sizeof('..me[1]..')'
        me.lval = false
    end,

    STRING = function (me)
        me.tp   = 'char*'
        me.val  = me[1]
        me.lval = false
    end,
    CONST = function (me)
        me.tp   = 'int'
        me.val  = me[1]
        me.lval = false
    end,
    NULL = function (me)
        me.tp   = 'void*'
        me.val  = '((void *)0)'
        me.lval = false
    end,
}

_VISIT(F)
