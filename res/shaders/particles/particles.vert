#version 430

layout(location = 0) in vec3 vertexPosition;
layout(location = 1) in vec2 vertexTexcoord;

layout(location = 0) uniform mat4 mvp;

struct Particle {
    vec2 position;
    vec2 velocity;
    float lifetime;
    float age;
    vec2 scale;
};

layout(binding = 0, std430) buffer ParticlesBuffer {
    Particle particles[];
};

out vec2 fragTexcoord;

void main() {
    Particle p = particles[gl_InstanceID];
    gl_Position = mvp * vec4(vertexPosition * vec3(p.scale, 1.0) + vec3(p.position, 0.0), 1.0);
    fragTexcoord = vertexTexcoord;
}