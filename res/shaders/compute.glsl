#version 430

layout(set = 0, binding = 0, std430) buffer Data {
    int nums[];
};

layout(local_size_x = 64, local_size_y = 1, local_size_z = 1) in;
void main() {
    int id = int(gl_GlobalInvocationID.x);
    nums[id] *= 2;
    // nums[id] = 110;
}