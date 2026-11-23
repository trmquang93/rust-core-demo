//! Shared game logic (2048 rules). One implementation, used by iOS and Android UIs.
use std::sync::Mutex;

uniffi::setup_scaffolding!();

#[derive(Clone, Copy, Debug, uniffi::Enum)]
pub enum Direction {
    Up,
    Down,
    Left,
    Right,
}

/// Slide one line toward index 0, merging equal neighbours once. Returns (line, points).
fn slide_line(line: [u32; 4]) -> ([u32; 4], u32) {
    let mut out = [0u32; 4];
    let mut n = 0;
    let mut points = 0;
    let mut last_merged = false;
    for v in line.into_iter().filter(|v| *v != 0) {
        if n > 0 && out[n - 1] == v && !last_merged {
            out[n - 1] *= 2;
            points += out[n - 1];
            last_merged = true;
        } else {
            out[n] = v;
            n += 1;
            last_merged = false;
        }
    }
    (out, points)
}

/// A spot inside a line, as seen when sliding in `dir`.
#[derive(Clone, Copy)]
struct LinePos {
    dir: Direction,
    /// Which row (Left/Right) or column (Up/Down), 0..4.
    line: usize,
    /// Distance from the edge the tiles slide toward, 0..4.
    pos: usize,
}

/// A cell's coordinates on the board.
#[derive(Clone, Copy)]
struct CellPos {
    row: usize,
    col: usize,
}

impl CellPos {
    /// Index into the flat, row-major `cells` array.
    fn index(self) -> usize {
        self.row * 4 + self.col
    }
}

/// Board cell that a line spot refers to.
fn cell_of(p: LinePos) -> CellPos {
    let LinePos { dir, line, pos } = p;
    match dir {
        Direction::Left => CellPos { row: line, col: pos },
        Direction::Right => CellPos { row: line, col: 3 - pos },
        Direction::Up => CellPos { row: pos, col: line },
        Direction::Down => CellPos { row: 3 - pos, col: line },
    }
}

struct State {
    cells: [u32; 16],
    score: u32,
    rng: u64,
}

impl State {
    fn next_rand(&mut self) -> u64 {
        // xorshift64*: deterministic, so the same seed gives the same game on every platform.
        self.rng ^= self.rng >> 12;
        self.rng ^= self.rng << 25;
        self.rng ^= self.rng >> 27;
        self.rng.wrapping_mul(0x2545_F491_4F6C_DD1D)
    }

    fn spawn(&mut self) {
        let empty: Vec<usize> = (0..16).filter(|&i| self.cells[i] == 0).collect();
        if empty.is_empty() {
            return;
        }
        let r = self.next_rand();
        let cell = empty[(r % empty.len() as u64) as usize];
        self.cells[cell] = if (r >> 32) % 10 == 0 { 4 } else { 2 };
    }

    /// The 4 values of one line, read in the direction tiles slide.
    fn line(&self, dir: Direction, line: usize) -> [u32; 4] {
        [0, 1, 2, 3].map(|pos| self.cells[cell_of(LinePos { dir, line, pos }).index()])
    }

    fn slide(&mut self, dir: Direction) -> bool {
        let mut moved = false;
        for i in 0..4 {
            let line = self.line(dir, i);
            let (new, points) = slide_line(line);
            if new != line {
                moved = true;
            }
            self.score += points;
            for j in 0..4 {
                self.cells[cell_of(LinePos { dir, line: i, pos: j }).index()] = new[j];
            }
        }
        if moved {
            self.spawn();
        }
        moved
    }

    fn is_over(&self) -> bool {
        if self.cells.contains(&0) {
            return false;
        }
        [Direction::Left, Direction::Up]
            .iter()
            .all(|&d| (0..4).all(|i| slide_line(self.line(d, i)).0 == self.line(d, i)))
    }
}

#[derive(uniffi::Object)]
pub struct Game {
    state: Mutex<State>,
}

#[uniffi::export]
impl Game {
    #[uniffi::constructor]
    pub fn new(seed: u64) -> Self {
        let mut s = State { cells: [0; 16], score: 0, rng: seed | 1 };
        s.spawn();
        s.spawn();
        Self { state: Mutex::new(s) }
    }

    /// Returns true if the board changed.
    pub fn slide(&self, dir: Direction) -> bool {
        self.state.lock().unwrap().slide(dir)
    }

    /// 16 values, row-major. 0 = empty.
    pub fn cells(&self) -> Vec<u32> {
        self.state.lock().unwrap().cells.to_vec()
    }

    pub fn score(&self) -> u32 {
        self.state.lock().unwrap().score
    }

    pub fn is_over(&self) -> bool {
        self.state.lock().unwrap().is_over()
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn merges_each_pair_once() {
        assert_eq!(slide_line([2, 2, 2, 2]), ([4, 4, 0, 0], 8));
        assert_eq!(slide_line([2, 2, 4, 0]), ([4, 4, 0, 0], 4));
        assert_eq!(slide_line([4, 2, 2, 0]), ([4, 4, 0, 0], 4));
    }

    #[test]
    fn right_slide_moves_tiles_to_the_right_edge() {
        let mut s = State { cells: [0; 16], score: 0, rng: 1 };
        s.cells[0] = 2;
        s.cells[1] = 2;
        assert!(s.slide(Direction::Right));
        assert_eq!(s.cells[3], 4);
        assert_eq!(s.score, 4);
    }

    #[test]
    fn same_seed_same_game() {
        let (a, b) = (Game::new(42), Game::new(42));
        for d in [Direction::Left, Direction::Up, Direction::Right, Direction::Down] {
            a.slide(d);
            b.slide(d);
        }
        assert_eq!(a.cells(), b.cells());
    }

    #[test]
    fn full_board_without_merges_is_over() {
        let s = State {
            cells: [2, 4, 2, 4, 4, 2, 4, 2, 2, 4, 2, 4, 4, 2, 4, 2],
            score: 0,
            rng: 1,
        };
        assert!(s.is_over());
    }
}
