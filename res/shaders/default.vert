#version 430

layout(location = 0) in vec2 position;
layout(location = 1) in vec3 color;

uniform mat4 mvp;

out vec4 fragColor;

void main() {
    fragColor = vec4(color, 1.0);
    gl_Position = mvp * vec4(position, 0.0, 1.0);
}