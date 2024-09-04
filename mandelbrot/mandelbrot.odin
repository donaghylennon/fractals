package mandelbrot

import "core:math"

import rl "vendor:raylib"

win_width :: 1000
win_height :: 600

main :: proc() {
    rl.InitWindow(win_width, win_height, "Mandelbrot")
    defer rl.CloseWindow()
    rl.SetExitKey(.Q)
    rl.SetTargetFPS(60)

    for !rl.WindowShouldClose() {
        rl.BeginDrawing()
            rl.ClearBackground(rl.RAYWHITE)
            {
                context.allocator = context.temp_allocator
                set := mandelbrot_set(-2.5, 2.5, -1.5, 1.5, 50, win_width, win_height)
                for x in 0..<len(set) {
                    for y in 0..<len(set[0]) {
                        result := set[x][y]
                        adj := u8(f64(result)/50 * 255)
                        rl.DrawPixel(i32(x), i32(y), rl.Color{adj, adj, adj, 255})
                    }
                }
            }
            rl.DrawFPS(10, 10)
        rl.EndDrawing()
        free_all(context.temp_allocator)
    }
}

mandelbrot :: proc(z, c: complex64) -> complex64 {
    return z*z + c
}

mandelbrot_set :: proc(x_low, x_high, y_low, y_high: f64, iterations: int, $N, $M: int) -> (results: ^[N][M]int) {
    results = new([N][M]int)
    x_range := x_high - x_low
    x_step := x_range/f64(N)
    y_range := y_high - y_low
    y_step := y_range/f64(M)
    for i in 0..<N {
        x := x_low + f64(i)*x_step
        for j in 0..<M {
            y := y_low + f64(j)*y_step

            z := complex64(0)
            found := false
            for iter in 0..<iterations {
                z = mandelbrot(z, complex(x, y))
                if math.abs(z) > 2 {
                    results[i][j] = iter
                    break
                }
            }
        }
    }
    return
}
