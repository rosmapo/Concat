// SPDX-License-Identifier: AGPL-3.0-or-later
// SPDX-FileCopyrightText: 2026 Concat contributors

// Page Turn: the outgoing shot is a sheet of paper rolled up from one edge
// round a cylinder, as a page of a book is lifted and turned. Past the roll
// the sheet lies back on itself, showing its reverse with the print faint
// through the paper, and the shot that follows waits beneath it, shaded
// where the sheet hangs over it.
//
// The page is laid out along x, which is the frame's width for a turn from
// the right and its mirror for a turn from the left. The roll's axis sits at
// `c` and its radius is `curl`; `c` runs from the far edge to clear of the
// near one, so the whole sheet has gone by the end.

const PI: f32 = 3.14159265;

struct Params { direction: f32, curl: f32 }

// A point of the sheet, `s` along it and `v` up it, as a place in the frame.
fn on_frame(s: f32, v: f32, mirrored: bool) -> vec2<f32> {
    return vec2<f32>(select(s, 1.0 - s, mirrored), v);
}

// The reverse of the sheet: its own print through pale paper, lit by `shade`.
fn reverse(print: vec4<f32>, shade: f32) -> vec4<f32> {
    let paper = mix(print.rgb, vec3<f32>(0.9, 0.9, 0.9), 0.7);
    return vec4<f32>(paper * shade, print.a);
}

fn transition(uv: vec2<f32>, progress: f32) -> vec4<f32> {
    let p = clamp(progress, 0.0, 1.0);
    let r = clamp(params.curl, 0.02, 0.5);
    let mirrored = params.direction > 0.5;
    let x = select(uv.x, 1.0 - uv.x, mirrored);
    let v = uv.y;
    // The axis of the roll: at the far edge at the start, gone past the near
    // edge, roll and all, at the end.
    let c = 1.0 - p * (1.0 + 2.0 * r);

    // Behind the roll, the sheet lies back over itself, reverse side up.
    if (x <= c) {
        let s = 2.0 * c + PI * r - x;
        if (s <= 1.0) {
            return reverse(from_at(on_frame(s, v, mirrored)), 1.0);
        }
        // Past the end of the folded-back sheet: the shot as it was, in the
        // shadow of that end while it is near.
        let edge = 2.0 * c + PI * r - 1.0;
        var shade = 1.0;
        if (edge < c) {
            shade = 1.0 - 0.3 * exp(-(edge - x) / 0.06);
        }
        let flat_shot = from_at(on_frame(x, v, mirrored));
        return vec4<f32>(flat_shot.rgb * shade, flat_shot.a);
    }

    // On the roll: the reverse over the crest, the face under it.
    if (x <= c + r) {
        let q = clamp((x - c) / r, 0.0, 1.0);
        let turn = asin(q);
        let s_reverse = c + r * (PI - turn);
        if (s_reverse <= 1.0) {
            return reverse(from_at(on_frame(s_reverse, v, mirrored)), mix(1.0, 0.55, q));
        }
        let s_face = c + r * turn;
        if (s_face <= 1.0) {
            let face = from_at(on_frame(s_face, v, mirrored));
            return vec4<f32>(face.rgb * mix(1.0, 0.6, q), face.a);
        }
    }

    // Beyond the roll: the next shot, shaded where the sheet hangs over it.
    let gap = max(x - (c + r), 0.0);
    let shade = 1.0 - 0.35 * exp(-gap / (0.7 * r + 0.03)) * min(p * 8.0, 1.0);
    let next = to_at(uv);
    return vec4<f32>(next.rgb * shade, next.a);
}
