package main

import "core:math"
import "core:math/linalg"

v2 :: [2]f32;
v3 :: [3]f32;
v4 :: [4]f32;

Transform_2D :: matrix[3, 3]f32;
IDENT_TRANSFORM_2D: Transform_2D : 1;
Transform_3D :: matrix[4, 4]f32;
IDENT_TRANSFORM_3D: Transform_3D : 1;

barycentric_weights :: proc(p, p1, p2, p3: v2) -> (f32, f32, f32){
    // source: https://codeplea.com/triangular-interpolation
    
    w1 := ((p2.y - p3.y) * (p.x - p3.x) + (p3.x - p2.x)*(p.y - p3.y)) / ((p2.y - p3.y)*(p1.x - p3.x) + (p3.x - p2.x)*(p1.y - p3.y));
    w2 := ((p3.y - p1.y) * (p.x - p3.x) + (p1.x - p3.x)*(p.y - p3.y)) / ((p2.y - p3.y)*(p1.x - p3.x) + (p3.x - p2.x)*(p1.y - p3.y));
    w3 := 1 - w1 - w2;

    return w1, w2, w3;
}

point_in_triangle2d :: proc(p, t1, t2, t3: v2) -> bool{
    // point = a  + w1 * (b - a) + w2 * (c - a)
    // w1 < 1, w2 < 1, 0 < w1 + w2 < 1 has to be true

    b1 := aux(p, t1, t2) < 0;  
    b2 := aux(p, t2, t3) < 0;
    b3 := aux(p, t3, t1) < 0;
    return ((b1 == b2) && (b2 == b3));

    aux :: proc(p1, p2, p3: v2) -> f32{  
        return (p1.x - p3.x) * (p2.y - p3.y) - (p2.x - p3.x) * (p1.y - p3.y);
    }
}

matrix2_2_from_v2 :: proc(a, b: v2) -> matrix[2, 2]f32{
    return {
        a.x, b.x,
        a.y, b.y,
    };
}

matrix3_3_from_v3 :: proc(a, b, c: v3) -> matrix[3, 3]f32{
    return {
        a.x, b.x, c.x,
        a.y, b.y, c.y,
        a.z, b.z, c.z,
    };
}

v2_det :: proc(a, b: v2) -> f32{
    return a.x * b.y - a.y * b.x;
}

v3_det :: proc(a, b, c: v3) -> f32{
    return linalg.determinant(matrix3_3_from_v3(a, b, c));
}

v_det :: proc{
    v2_det,
    v3_det,
};


translate_2d :: proc(pos: v2) -> Transform_2D{
    return {
        1, 0, pos.x,
        0, 1, pos.y,
        0, 0, 1,
    };
}

shear_x_2d :: proc(degree: f32) -> Transform_2D{
    t := math.tan(math.to_radians(degree));
    return {
        1, t, 0,
        0, 1, 0,
        0, 0, 1,
    };
}

shear_y_2d :: proc(degree: f32) -> Transform_2D{
    t := math.tan(math.to_radians(degree));
    return { 
        1, 0, 0,
        t, 1, 0,
        0, 0, 1,
    };
}

// Counter-Clockwise
rotation_2d :: proc(degree: f32) -> Transform_2D{
    r := math.to_radians(degree);
    s := math.sin(r);
    c := math.cos(r);
    return {
        c, -s, 0,
        s,  c, 0,
        0,  0, 1,
    };
}

scale_2d :: proc(scaler: v2) -> Transform_2D{
    return { 
        scaler.x,        0, 0,
        0,        scaler.y, 0,
        0,               0, 1,
    };
}

// Apllies the first and then the second
combine_2d :: proc(transfomrs: ..Transform_2D) -> Transform_2D{
    combined: Transform_2D = 1;
    #reverse for t in transfomrs{
        combined = combined * t;
    }
    return combined;
}

apply_2d :: proc(p: v2, transform: Transform_2D) -> v2{
    v: v3 = {p.x, p.y, 1};
    r := transform * v;
    return r.xy;
}

scale_3d :: proc(scaler: v3) -> Transform_3D{
    return { 
        scaler.x,        0,        0, 0,
        0,        scaler.y,        0, 0,
        0,               0, scaler.z, 0,
        0,               0,        0, 1,
    };
}

translate_3d :: proc(translation: v3) -> Transform_3D{
    return { 
        1, 0, 0, translation.x,
        0, 1, 0, translation.y,
        0, 0, 1, translation.z,
        0, 0, 0, 1,
    };
}

normal_transform :: proc(transform: Transform_3D) -> Transform_3D{
    // Todo(Ferenc): unroll calculations
    m: matrix[3, 3]f32 = {
        transform[0, 0], transform[1, 0], transform[2, 0],
        transform[0, 1], transform[1, 1], transform[2, 1],
        transform[0, 2], transform[1, 2], transform[2, 2],
    };

    t := linalg.transpose(linalg.inverse(m)); 
    return {
        t[0, 0], t[1, 0], t[2, 0], 0,
        t[0, 1], t[1, 1], t[2, 1], 0,
        t[0, 2], t[1, 2], t[2, 2], 0,
        0,       0,       0,       1,
    };
}

combine :: proc{
    combine_2d,
}

apply :: proc{
    apply_2d,
}

remap :: proc(x, froma, toa, fromb, tob: f32) -> f32 {
	return linalg.lerp(
		fromb, tob, \
		linalg.unlerp(froma, toa, x), \
	);
}

// easing functions
ease_in_out_cubic :: proc(x: f32) -> f32 {
	if x < 0.5 {
		return 4 * x * x * x;
	} else {
		return 1 - linalg.pow(-2 * x + 2, 3) / 2;
	}
}

ease_out_cubic :: proc(x: f32) -> f32 {
	return 1 - linalg.pow(1 - x, 3);
}
