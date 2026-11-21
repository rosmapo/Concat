// SPDX-License-Identifier: AGPL-3.0-or-later
// SPDX-FileCopyrightText: 2026 Concat contributors

// Page Turn: the outgoing shot is a sheet of paper peeled back from one
// corner, rolled up round a cylinder as the page of a book is lifted. Past
// the roll the sheet lies back over itself, showing its reverse with the
// picture faintly through the paper, and the shot that follows waits
// beneath it, shaded where the sheet hangs over it.
//
// Everything is worked in pixels in a frame flipped so that the corner the
// peel starts from is the far one, (size.x, size.y). The sheet is measured
// along DIR, the way the peel travels, and across it along NRM. The axis
// of the roll sits at `c` along DIR, and runs from the far corner at the
// start to clear of the near one, roll and all, at the end.

const PI: f32 = 3.14159265;

// The way the peel travels, 30 degrees up from the horizontal, and across it.
const DIR: vec2<f32> = vec2<f32>(0.8660254, 0.5);
const NRM: vec2<f32> = vec2<f32>(-0.5, 0.8660254);

struct Params { corner: f32, curl: f32 }

// A point of the frame, flipped to put the peel's corner far, or back.
fn flip_uv(u: vec2<f32>, flip_x: bool, flip_y: bool) -> vec2<f32> {
    return vec2<f32>(select(u.x, 1.0 - u.x, flip_x), select(u.y, 1.0 - u.y, flip_y));
}

// Whether a point, in pixels, is on the sheet.
fn on_page(q: vec2<f32>, size: vec2<f32>) -> bool {
    return q.x >= 0.0 && q.y >= 0.0 && q.x <= size.x && q.y <= size.y;
}

// 1 where the sheet folded back over itself covers the point at `t` along
// DIR and `w` across it, else 0.
fn hangs(t: f32, w: f32, c: f32, r: f32, size: vec2<f32>) -> f32 {
    if (t > c) {
        return 0.0;
    }
    let q = DIR * (2.0 * c + PI * r - t) + NRM * w;
    return select(0.0, 1.0, on_page(q, size));
}

// The reverse of the sheet: the picture through pale paper, lit by `shade`.
fn reverse(print: vec4<f32>, shade: f32) -> vec4<f32> {
    let paper = mix(print.rgb, vec3<f32>(0.95, 0.95, 0.95), 0.25);
    return vec4<f32>(paper * shade, print.a);
}

fn transition(uv: vec2<f32>, progress: f32) -> vec4<f32> {
    let p = clamp(progress, 0.0, 1.0);
    let size = frame.size;
    let corner = i32(round(clamp(params.corner, 0.0, 3.0)));
    let flip_x = corner >= 2;
    let flip_y = corner == 1 || corner == 3;
    let pos = flip_uv(uv, flip_x, flip_y) * size;
    let r = clamp(params.curl, 0.02, 0.5) * size.y;
    let t = dot(pos, DIR);
    let w = dot(pos, NRM);
    let far = dot(size, DIR);
    let c = far - p * (far + 2.0 * r);

    // Behind the roll the sheet lies back over itself, reverse side up.
    if (t <= c) {
        let s = 2.0 * c + PI * r - t;
        let q = DIR * s + NRM * w;
        if (on_page(q, size)) {
            return reverse(from_at(flip_uv(q / size, flip_x, flip_y)), 1.0);
        }
        // Not under the folded-back sheet: the shot as it was, in the
        // shadow of the sheet's edge while that is near.
        let hang = hangs(t + 0.02 * size.y, w, c, r, size)
            + hangs(t + 0.05 * size.y, w, c, r, size)
            + hangs(t + 0.09 * size.y, w, c, r, size);
        let flat_shot = from_at(uv);
        return vec4<f32>(flat_shot.rgb * (1.0 - 0.12 * hang), flat_shot.a);
    }

    // On the roll: the reverse over the crest, the face under it.
    if (t <= c + r) {
        let q01 = clamp((t - c) / r, 0.0, 1.0);
        let turn = asin(q01);
        let q_reverse = DIR * (c + r * (PI - turn)) + NRM * w;
        if (on_page(q_reverse, size)) {
            let print = from_at(flip_uv(q_reverse / size, flip_x, flip_y));
            return reverse(print, mix(1.0, 0.55, q01));
        }
        let q_face = DIR * (c + r * turn) + NRM * w;
        if (on_page(q_face, size)) {
            let face = from_at(flip_uv(q_face / size, flip_x, flip_y));
            return vec4<f32>(face.rgb * mix(1.0, 0.6, q01), face.a);
        }
    }

    // Beyond the roll: the next shot, shaded where the sheet hangs over it.
    let gap = max(t - (c + r), 0.0);
    let shade = 1.0 - 0.35 * exp(-gap / (0.7 * r + 0.03 * size.y)) * min(p * 8.0, 1.0);
    let next = to_at(uv);
    return vec4<f32>(next.rgb * shade, next.a);
}
