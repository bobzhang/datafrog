use datafrog::{Iteration, Relation, RelationLeaper};
use std::io::{self, BufRead};
fn encode(values: &[(u32,u32)]) -> String {
    values.iter().map(|(a,b)| format!("{a},{b}")).collect::<Vec<_>>().join(";")
}
fn closure(edges: &[(u32,u32)], mode: u32) -> String {
    let mut i = Iteration::new();
    let paths = i.variable("paths");
    let incoming: Relation<_> = edges.iter().map(|&(a,b)| (b,a)).collect();
    paths.extend(edges.iter().copied());
    while i.changed() {
        if mode == 1 { paths.from_join(&paths, &incoming, |&_, &c, &a| (a,c)); }
        else { paths.from_leapjoin(&paths, incoming.extend_with(|&(b,_)| b), |&(_,c), &a| (a,c)); }
    }
    encode(&paths.complete().elements)
}
fn evaluate(seed: u32) -> String {
    let n = 3 + seed % 22;
    let mut random = seed;
    let mut edges = vec![];
    let mut i = Iteration::new();
    let paths = i.variable("paths");
    let incoming = i.variable("incoming");
    let mut results = vec![];
    for phase in 0..2 {
        let count = if phase == 0 { seed % (n*2) + 1 } else { n/2+1 };
        let mut batch = vec![];
        for _ in 0..count {
            random = random.wrapping_mul(1664525).wrapping_add(1013904223);
            let a = (random >> 8) % n;
            random = random.wrapping_mul(1664525).wrapping_add(1013904223);
            let b = (random >> 8) % n;
            batch.push((a,b)); edges.push((a,b));
        }
        paths.extend(batch.iter().copied());
        incoming.extend(batch.iter().map(|&(a,b)| (b,a)));
        while i.changed() { paths.from_join(&paths, &incoming, |&_, &c, &a| (a,c)); }
        // Upstream complete consumes/drains shared state; inspect stable batches for staged resumption.
        let snapshot: Relation<_> = paths.stable.borrow().iter().flat_map(|r| r.elements.iter().copied()).collect();
        results.push(encode(&snapshot.elements));
        results.push(closure(&edges, 1)); results.push(closure(&edges, 2));
    }
    results.join("|")
}
fn main() {
    for line in io::stdin().lock().lines() { println!("{}", evaluate(line.unwrap().parse().unwrap())); }
}
