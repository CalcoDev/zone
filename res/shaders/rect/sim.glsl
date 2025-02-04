#version 430

layout(binding = 0, std430) buffer PositionsBuffer {
    vec3 positions[];
};
layout(binding = 1, std430) buffer VelocityBuffer {
    vec2 velocities[];
};

layout(local_size_x = 64, local_size_y = 1, local_size_z = 1) in;
void main() {
    int i = int(gl_GlobalInvocationID.x);
    positions[i] += vec3(velocities[i], 0.0);
    // positions[i] += vec3(0.1);
}