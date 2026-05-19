#version 460 core
#include <flutter/runtime_effect.glsl>

// Calm pond water: idle ripples, touch ripples, dim face reflections.
// Uniform float order MUST match WaterPainter.setFloat order exactly.

uniform vec2 uResolution;       // 0,1
uniform float uTime;            // 2  (seconds)
uniform float uRippleCount;     // 3
uniform vec4 uRipples[12];      // 4..51  (xy=center px, z=age s, w=strength)
uniform float uFaceLocalOn;     // 52
uniform float uFaceRemoteOn;    // 53
uniform sampler2D uFaceLocal;   // sampler 0
uniform sampler2D uFaceRemote;  // sampler 1

out vec4 fragColor;

void main() {
  vec2 frag = FlutterFragCoord().xy;
  vec2 uv = frag / uResolution;
  float t = uTime;

  // --- idle gentle surface motion ---
  vec2 disp = vec2(0.0);
  disp.x += sin(uv.y * 14.0 + t * 0.70) * 1.6;
  disp.y += cos(uv.x * 11.0 + t * 0.60) * 1.6;
  disp += vec2(
    sin((uv.x + uv.y) * 7.0 + t * 0.40),
    cos((uv.x - uv.y) * 6.0 - t * 0.50)
  ) * 1.1;

  // --- touch ripples ---
  float highlight = 0.0;
  int n = int(uRippleCount + 0.5);
  for (int i = 0; i < 12; i++) {
    if (i >= n) break;
    vec4 r = uRipples[i];
    float age = r.z;
    float strength = r.w;
    vec2 d = frag - r.xy;
    float dist = length(d);
    float front = age * 220.0;          // px/s wave front
    float band = dist - front;
    float ringW = 46.0;
    float ring = exp(-(band * band) / (2.0 * ringW * ringW));
    float decay = exp(-age * 1.6) * strength;
    float wave = sin(band * 0.20) * ring * decay;
    vec2 dir = dist > 0.001 ? d / dist : vec2(0.0);
    disp += dir * wave * 26.0;
    highlight += ring * decay * 0.9;
  }

  // --- water base color ---
  vec2 wuv = uv + disp / uResolution;
  vec3 deep = vec3(0.016, 0.055, 0.075);
  vec3 shallow = vec3(0.040, 0.130, 0.160);
  vec3 col = mix(deep, shallow, clamp(wuv.y * 0.9 + 0.1, 0.0, 1.0));
  float sheen = 0.5 + 0.5 * sin((wuv.x + wuv.y) * 9.0 + t * 0.8);
  col += sheen * 0.015;

  // --- dim face reflections ---
  // local: lower half mirrored; remote: upper half.
  vec2 fuv = clamp(wuv + disp / uResolution * 1.5, 0.0, 1.0);

  if (uFaceLocalOn > 0.5 && wuv.y > 0.5) {
    vec2 s = clamp(vec2(fuv.x, (1.0 - fuv.y) * 2.0), 0.0, 1.0);
    vec3 face = texture(uFaceLocal, s).rgb;
    float fade = smoothstep(0.5, 0.85, wuv.y) * 0.14;
    col = mix(col, col + face * 0.6, fade);
  }
  if (uFaceRemoteOn > 0.5 && wuv.y < 0.5) {
    vec2 s = clamp(vec2(fuv.x, fuv.y * 2.0), 0.0, 1.0);
    vec3 face = texture(uFaceRemote, s).rgb;
    float fade = smoothstep(0.5, 0.15, wuv.y) * 0.14;
    col = mix(col, col + face * 0.6, fade);
  }

  col += highlight * vec3(0.10, 0.16, 0.18);
  fragColor = vec4(col, 1.0);
}
