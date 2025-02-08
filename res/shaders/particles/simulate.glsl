#version 430

struct Particle {
    vec2 position;
    vec2 velocity;
    float lifetime;
    float age;
    vec2 scale;
};

layout(location = 0) uniform float u_delta;

layout(binding = 0, std430) buffer ParticlesBuffer {
    Particle particles[];
};

layout(local_size_x = 64, local_size_y = 1, local_size_z = 1) in;
void main() {
    int i = int(gl_GlobalInvocationID.x);
    particles[i].lifetime -= u_delta;
    particles[i].age += u_delta;
    float maxLife = particles[i].lifetime + particles[i].age;
    particles[i].scale = (5.0 - particles[i].age) / 5.0 * vec2(2.0);
}