package mandelbrot

import "core:math"
import "core:math/linalg"
import "core:thread"

import rl "vendor:raylib"

win_width :: 500
win_height :: 300

iterations :: 50

main :: proc() {
    rl.InitWindow(win_width, win_height, "Mandelbrot")
    defer rl.CloseWindow()
    rl.SetExitKey(.Q)
    rl.SetTargetFPS(60)

    startpos := [2]f64 {-2.5, -1.5}
    endpos := [2]f64 {2.5, 1.5}

    mousedown := false
    mousestartpos: [2]f32
    mouseendpos: [2]f32

    results := new([win_width][win_height]int)
    defer free(results)

    for !rl.WindowShouldClose() {
        rl.BeginDrawing()
            rl.ClearBackground(rl.RAYWHITE)
            {
                mandelbrot_set(startpos.x, startpos.y, endpos.x, endpos.y, iterations, win_width, win_height, results)
                for x in 0..<win_width {
                    for y in 0..<win_height {
                        result := results[x][y]
                        adj := u8(f64(result)/iterations * 255)
                        rl.DrawPixel(i32(x), i32(y), rl.Color{adj, adj, adj, 255})
                    }
                }
            }
            if mousedown {
                rectsize := rl.GetMousePosition() - mousestartpos
                rl.DrawRectangleLines(i32(mousestartpos.x), i32(mousestartpos.y), i32(rectsize.x), i32(rectsize.y), rl.RAYWHITE)
                rl.DrawRectangleLinesEx(rl.Rectangle{mousestartpos.x, mousestartpos.y, rectsize.x, rectsize.y}, 5, rl.RAYWHITE)
            }

            rl.DrawFPS(10, 10)
        rl.EndDrawing()

        if !mousedown && rl.IsMouseButtonPressed(.LEFT) {
            mousedown = true
            mousestartpos = rl.GetMousePosition()
        }
        if mousedown && rl.IsMouseButtonReleased(.LEFT) {
            mousedown = false
            mouseendpos = rl.GetMousePosition()

            real_range := endpos - startpos

            realstartpos := startpos + (linalg.to_f64(mousestartpos) / {win_width, win_height} * real_range)
            realendpos := startpos + (linalg.to_f64(mouseendpos) / {win_width, win_height} * real_range)

            startpos = realstartpos
            endpos = realendpos
        }

        results^ = {}
    }
}

mandelbrot :: proc(z, c: complex64) -> complex64 {
    return z*z + c
}

mandelbrot_set :: proc(x_low, y_low, x_high, y_high: f64, $iterations: int, $N, $M: int, results: ^[N][M]int) {
    nthreads :: 24
    bucket_size :: N*M/nthreads
    x_low := x_low
    y_low := y_low
    x_range := x_high - x_low
    x_step := x_range/f64(N)
    y_range := y_high - y_low
    y_step := y_range/f64(M)

    worker_proc :: proc(t: ^thread.Thread) {
        thread_idx := t.user_index
        x_low := (^f64)(t.user_args[1])^
        y_low := (^f64)(t.user_args[2])^
        x_step := (^f64)(t.user_args[3])^
        y_step := (^f64)(t.user_args[4])^
        for bucket_idx in 0..<bucket_size {
            index := thread_idx*bucket_size + bucket_idx
            i := index / M
            j := index % M
            x := x_low + f64(i)*x_step
            y := y_low + f64(j)*y_step

            result := &(^[N][M]int)(t.user_args[0])[i][j]
            z := complex64(0)

            for iter in 0..<iterations {
                z = mandelbrot(z, complex(x, y))
                if math.abs(z) > 2 {
                    result^ = iter
                    break
                }
            }
        }
    }

    threads := make([dynamic]^thread.Thread, 0, nthreads)
    defer delete(threads)
    for i in 0..<nthreads {
        if t := thread.create(worker_proc); t != nil {
            t.user_args[0] = results
            t.user_args[1] = &x_low
            t.user_args[2] = &y_low
            t.user_args[3] = &x_step
            t.user_args[4] = &y_step
            t.user_index = i
            append(&threads, t)
            thread.start(t)
        }
    }
    for len(threads) > 0 {
        for i := 0; i < len(threads); {
            if t := threads[i]; thread.is_done(t) {
                thread.destroy(t)
                ordered_remove(&threads, i)
            } else {
                i += 1
            }
        }
    }
    return
}
