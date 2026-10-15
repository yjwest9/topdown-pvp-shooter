# 사용: python tool/duel_map_gen.py assets/maps/duel.tmx  (그다음 flutter test tool/map_preview_test.dart)
"""1대1 전용 맵 생성(outpost_map_gen.py와 같은 방식): A쪽 절반을 사각형으로 적고 180도 회전으로
나머지를 만든다. 칸 70px, 17x17. 출력: Tiled tmx(오브젝트 레이어만) + 콘솔 ASCII."""
import sys
N = 17
C = 70

def rot(r):  # (c0,r0,c1,r1) 180도 회전
    c0, r0, c1, r1 = r
    return (N-1-c1, N-1-r1, N-1-c0, N-1-r0)

floor_a = [
    (6, 13, 10, 15),   # A 진영(3줄)
    (8, 12, 8, 12),    # 진영 문(가운데 하나)
    (1, 8, 15, 11),    # 전장 A쪽 절반 + 가운데 줄(회전하면 5~8줄)
    (2, 12, 4, 12),    # 진영 왼쪽 틈 공간
    (12, 12, 14, 12),  # 진영 오른쪽 틈 공간
]
wall_a = [
    (7, 14, 9, 14),    # 진영 안 가림벽(양 끝 6·10열만 뚫림)
    (8, 7, 8, 9),      # 가운데 세로 기둥(자기 대칭, 문↔문 일직선 막음)
    (3, 10, 4, 10),    # 왼쪽 기둥
    (12, 9, 12, 10),   # 오른쪽 기둥
]
crate_a = [
    (6, 10, 6, 10), (10, 10, 10, 10),  # 문 나와서 바로 숨는 상자
    (5, 8, 6, 8),                      # 가운데 줄, 기둥 옆
    (1, 10, 1, 10),                    # 왼쪽 가장자리
    (14, 10, 14, 11),                  # 오른쪽 가장자리 긴 상자
    (3, 12, 3, 12),                    # 왼쪽 틈 공간
    (12, 12, 12, 12),                  # 오른쪽 틈 공간, 올라가서 전장 내려다보는 자리
]
spawn_a = [(7, 15), (8, 15), (9, 15)]
base_a = (6, 13, 10, 15)

grid = [['#'] * N for _ in range(N)]
def fill(rects, ch):
    for r in rects:
        for rr in (r, rot(r)):
            c0, r0, c1, r1 = rr
            for y in range(r0, r1+1):
                for x in range(c0, c1+1):
                    grid[y][x] = ch
fill(floor_a, '.')
fill(wall_a, '#')
fill(crate_a, 'c')

# 원 안에 들어가는지(걸을 수 있는 칸 중심이 반지름 15.5칸 안)
cx = cy = (N-1)/2
far = max(((x-cx)**2+(y-cy)**2)**0.5 for y in range(N) for x in range(N) if grid[y][x] != '#')
# 대칭 확인
for y in range(N):
    for x in range(N):
        assert grid[y][x] == grid[N-1-y][N-1-x]

def rects_of(ch):
    """같은 글자 칸을 큰 사각형으로 묶는다(탐욕). 절반만 묶고 180도 회전으로 나머지를
    만들어서 사각형 목록도 대칭이 되게 한다."""
    half = lambda x, y: y < N // 2 or (y == N // 2 and x <= N // 2)
    ok = lambda x, y: grid[y][x] == ch and half(x, y) and not used[y][x]
    used = [[False]*N for _ in range(N)]
    out = []
    for y in range(N):
        for x in range(N):
            if not ok(x, y):
                continue
            w = 1
            while x+w < N and ok(x+w, y):
                w += 1
            h = 1
            while y+h < N and all(ok(x+i, y+h) for i in range(w)):
                h += 1
            for yy in range(y, y+h):
                for xx in range(x, x+w):
                    used[yy][xx] = True
            out.append((x, y, w, h))
    rotated = [(N - x - w, N - y - h, w, h) for (x, y, w, h) in out]
    return out + [r for r in rotated if r not in out]

for y in range(N):
    row = ''.join(grid[y])
    for (sx, sy) in spawn_a:
        if sy == y: row = row[:sx] + 'A' + row[sx+1:]
        if N-1-sy == y: row = row[:N-1-sx] + 'B' + row[N-1-sx+1:]
    print(row)
print('farthest walkable cell from center:', round(far, 2), 'cells')

walls = rects_of('#'); crates = rects_of('c')
oid = 1
def obj(x, y, w, h, props=None):
    global oid
    s = f'  <object id="{oid}" x="{x*C}" y="{y*C}" width="{w*C}" height="{h*C}"'
    oid += 1
    if props:
        return s + '>\n   <properties>\n' + ''.join(f'    <property name="{k}" value="{v}"/>\n' for k, v in props.items()) + '   </properties>\n  </object>\n'
    return s + '/>\n'
def point(px, py, team):
    global oid
    s = f'  <object id="{oid}" x="{px}" y="{py}">\n   <properties>\n    <property name="team" value="{team}"/>\n   </properties>\n   <point/>\n  </object>\n'
    oid += 1
    return s

out = [f'<?xml version="1.0" encoding="UTF-8"?>\n<map version="1.10" tiledversion="1.11.0" orientation="orthogonal" renderorder="right-down" width="{N}" height="{N}" tilewidth="{C}" tileheight="{C}" infinite="0" nextlayerid="5" nextobjectid="9999">\n']
out.append(' <objectgroup id="1" name="walls">\n' + ''.join(obj(*r) for r in walls) + ' </objectgroup>\n')
out.append(' <objectgroup id="2" name="crates">\n' + ''.join(obj(*r) for r in crates) + ' </objectgroup>\n')
b = base_a; rb = rot(b)
out.append(' <objectgroup id="4" name="bases">\n'
           + obj(b[0], b[1], b[2]-b[0]+1, b[3]-b[1]+1, {'team': 'A'})
           + obj(rb[0], rb[1], rb[2]-rb[0]+1, rb[3]-rb[1]+1, {'team': 'B'}) + ' </objectgroup>\n')
sp = ''.join(point(x*C+C//2, y*C+C//2, 'A') for x, y in spawn_a) + ''.join(point((N-1-x)*C+C//2, (N-1-y)*C+C//2, 'B') for x, y in spawn_a)
out.append(' <objectgroup id="3" name="spawns">\n' + sp + ' </objectgroup>\n</map>\n')
open(sys.argv[1], 'w', encoding='utf-8', newline='\n').write(''.join(out))
print('walls', len(walls), 'crates', len(crates))
