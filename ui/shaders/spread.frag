#version 440

// 像素扩散转场：新壁纸从若干随机种子点生长，吞噬旧图，边缘不规则且带辉光。
// 用 tools/build-shaders.sh 编译成 .qsb（Qt6 的 ShaderEffect 只吃预编译产物）。

layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

// std140 布局：qt_Matrix / qt_Opacity 必须在最前，内置顶点着色器要用。
// 之后 7 个 float 刚好填到 offset 96，vec4 从那里 16 字节对齐开始。
layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    float progress;    // 0..1
    float cell;        // 格子宽度，占画面宽度的比例
    float glow;        // 边缘辉光强度 0..1
    float irregular;   // 边缘不规则程度
    float seedValue;   // 随机种，同一个值出同一种生长图案
    float seedCount;   // 生长原点数量
    float aspect;      // width / height
    vec4 edgeColor;
};

layout(binding = 1) uniform sampler2D oldTex;
layout(binding = 2) uniform sampler2D newTex;

const int MAX_SEEDS = 32;
const float EDGE_WIDTH = 0.035;

float hash11(float p) {
    p = fract(p * 0.1031);
    p *= p + 33.33;
    p *= p + p;
    return fract(p);
}

vec2 hash21(float p) {
    vec3 p3 = fract(vec3(p) * vec3(0.1031, 0.1030, 0.0973));
    p3 += dot(p3, p3.yzx + 33.33);
    return fract((p3.xx + p3.yz) * p3.zy);
}

float hash12(vec2 p) {
    vec3 p3 = fract(vec3(p.xyx) * 0.1031);
    p3 += dot(p3, p3.yzx + 33.33);
    return fract((p3.x + p3.y) * p3.z);
}

void main() {
    vec2 uv = qt_TexCoord0;

    // 量化到方格 —— 这是"像素块"质感的来源。
    // x 方向用 cell，y 方向乘 aspect 才是正方形。
    vec2 q = max(vec2(cell, cell * aspect), vec2(1e-5));
    vec2 cuv = (floor(uv / q) + 0.5) * q;

    // 按宽高比修正，否则在非正方屏上生长是椭圆的
    vec2 p = vec2(cuv.x * aspect, cuv.y);

    // 多个种子竞争：每个像素取"最早被吞到"的那个时间
    float t = 1e9;
    for (int i = 0; i < MAX_SEEDS; ++i) {
        if (float(i) >= seedCount)
            break;
        float fi = float(i) + seedValue * 7.0;
        vec2 s = hash21(fi);
        float spd = 0.55 + hash11(fi + 91.7) * 0.9;   // 各自生长速度不同
        float off = hash11(fi + 173.3) * 0.4;         // 各自启动时间不同
        t = min(t, distance(p, vec2(s.x * aspect, s.y)) / spd + off);
    }

    // 软归一化 t/(t+k) 把 [0,∞) 映到 [0,1)。
    // 好处：progress=1 时一定全部揭示，不会出现末尾硬切。
    float tn = t / (t + 0.75);

    // 边缘打毛。注意这会把 tn 推出 [0,1) —— 下面必须把端点补回来。
    tn += (hash12(cuv * 97.0 + seedValue) - 0.5) * irregular;

    // 端点闭合：打毛后 tn ∈ [-irregular/2, 1+irregular/2]，
    // 若直接拿 progress 比较，progress=0 时会有散点提前露出 newTex、
    // progress=1 时会有散点还停在 oldTex —— 后者在动画结束交换缓冲的
    // 瞬间翻面，就是肉眼看到的「闪一下」。把 progress 映射到
    // [-m, 1+m] 之后两端都干净。
    float m = irregular * 0.5 + 0.01;
    float prog = progress * (1.0 + 2.0 * m) - m;

    float d = prog - tn;

    vec4 col = mix(texture(oldTex, uv), texture(newTex, uv), step(0.0, d));

    // 刚被吞掉的一条带子上叠辉光。
    // 末尾要淡出：否则 progress=1 那一帧还挂着一圈辉光，交换缓冲后突然消失。
    float e = (d > 0.0 && d < EDGE_WIDTH) ? (1.0 - d / EDGE_WIDTH) : 0.0;
    e *= 1.0 - smoothstep(0.88, 1.0, progress);
    col.rgb = mix(col.rgb, edgeColor.rgb, e * glow);

    fragColor = col * qt_Opacity;
}
