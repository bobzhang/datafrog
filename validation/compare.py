#!/usr/bin/env python3
"""Compare exact reachable pairs, all three join strategies, two insertion phases."""
import json
import pathlib
import subprocess
ROOT = pathlib.Path(__file__).resolve().parent.parent
PIN = 'edd7cfc0f5ad3b93ce5bbe6a17848db9376b13c0'
def run(args, **kwargs):
    return subprocess.run(args, cwd=ROOT, check=True, text=True, **kwargs)
assert run(['git', '-C', '.repos/datafrog', 'rev-parse', 'HEAD'], capture_output=True).stdout.strip() == PIN
assert not run(['git', '-C', '.repos/datafrog', 'status', '--porcelain'], capture_output=True).stdout.strip()
run(['cargo', 'build', '--release', '--locked', '--manifest-path', 'validation/rust/Cargo.toml'])
run(['moon', 'build', '--release', '--target', 'js'])
seeds = range(1, 513)
inputs = ''.join(f'{seed}\n' for seed in seeds)
rust = run(['validation/rust/target/release/datafrog-reference-check'], input=inputs, capture_output=True).stdout.splitlines()
moon = run(['node', 'validation/run.cjs'], input=inputs, capture_output=True).stdout.splitlines()
assert len(rust) == len(moon) == len(seeds)
for seed, r, m in zip(seeds, rust, moon):
    n = 3 + seed % 22
    state = seed
    edges = set()
    expected = []
    for phase in range(2):
        for _ in range(seed % (n * 2) + 1 if phase == 0 else n // 2 + 1):
            state = (state * 1664525 + 1013904223) & 0xffffffff
            a = (state >> 8) % n
            state = (state * 1664525 + 1013904223) & 0xffffffff
            edges.add((a, (state >> 8) % n))
        reachable = set()
        for start in range(n):
            todo = [b for a, b in edges if a == start]
            seen = set()
            while todo:
                node = todo.pop()
                if node not in seen:
                    seen.add(node)
                    todo.extend(b for a, b in edges if a == node)
            reachable.update((start, node) for node in seen)
        encoded = ';'.join(f'{a},{b}' for a, b in sorted(reachable))
        expected.extend([encoded] * 3)
    assert r == m == '|'.join(expected), f'differential failure at seed {seed}'
summary = {'upstream': PIN, 'seeds': len(seeds), 'insertion_phases': 2, 'strategies': ['dynamic join with resumed iteration', 'static join', 'leapjoin'], 'exact_comparisons': len(seeds)*6, 'oracle': 'independent Python graph search', 'status': 'passed'}
(ROOT/'validation/results.json').write_text(json.dumps(summary, indent=2)+'\n')
print(json.dumps(summary))
