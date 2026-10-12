# 사용: python tool/outpost_map_gen.py assets/maps/outpost.tmx  (그다음 flutter test tool/map_preview_test.dart)
"""새 진영 맵 생성: A쪽 절반을 사각형으로 적고 180도 회전으로 나머지를 만든다.
칸 70px, 31x31. 출력: Tiled tmx(오브젝트 레이어만) + 콘솔 ASCII."""
import sys
N = 31
C = 70

def rot(r):  # (c0,r0,c1,r1) 180도 회전
    c0, r0, c1, r1 = r
    return (N-1-c1, N-1-r1, N-1-c0, N-1-r0)

floor_a = [
    (11, 25, 19, 28),  # A 진영
    (11, 24, 11, 24), (19, 24, 19, 24),  # 진영 문 두 개(양 끝)
    (9, 21, 21, 23),   # 진영 앞 마당
    (5, 21, 8, 23),    # 마당 -> 왼쪽 길
    (2, 12, 4, 23),    # 왼쪽 긴 직선(상대 쪽 위에서 꺾임)
    (14, 18, 16, 20),  # 마당 -> 가운데 통로
    (11, 13, 19, 17),  # 가운데 광장(자기 대칭)
    (5, 15, 10, 16),   # 광장 -> 왼쪽 길 샛길
    (21, 18, 23, 20),  # 마당 -> 오른쪽 꺾인 길
    (24, 18, 28, 20),  # -> 오른쪽 직선(상대 쪽)의 아래 끝
]
wall_a = [
    # 진영 안 가림벽: 문(양 끝) -> 복도(25행) -> 가운데 틈 -> 스폰. 밖에서 스폰이 안 보이게
    # 틈을 문과 엇갈리게 둔다(frontline과 같은 방식).
    (11, 26, 14, 26), (16, 26, 19, 26),
]
crate_a = [
    (14, 15, 16, 15),                  # 광장 한가운데 긴 상자(자기 대칭)
    (12, 13, 12, 13), (12, 17, 12, 17),
    (2, 18, 2, 18), (4, 14, 4, 14),    # 왼쪽 직선 엄폐
    (23, 18, 23, 18),                  # 꺾인 길 모서리
    (10, 22, 10, 22), (20, 22, 20, 22),  # 마당
]
spawn_a = [(12, 28), (15, 28), (18, 28)]
base_a = (11, 25, 19, 28)

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
