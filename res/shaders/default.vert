#version 430

layout (location = 0) in vec2 vertexPosition;
layout (location = 1) in vec2 vertexTexCoord;
// layout (location = 2) in vec2 instancePosition;

// in vec3 vertexPosition;
// in vec2 vertexTexCoord;
// in vec3 vertexNormal;
// in vec4 vertexColor;

// Input uniform values
// uniform mat4 mvp;

// Output vertex attributes (to fragment shader)
// out vec2 fragTexCoord;
// out vec4 fragColor;

// NOTE: Add here your custom variables

void main()
{
    gl_Position = vec4(vertexPosition, 0.0, 0.0);
    // Send vertex attributes to fragment shader
    // fragTexCoord = vertexTexCoord;
    // fragColor = vertexColor;

    // Calculate final vertex position
    // gl_Position = mvp*vec4(vertexPosition, 1.0);
}