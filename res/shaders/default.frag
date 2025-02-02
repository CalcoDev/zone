#version 330

out vec4 finalColor;

// Input vertex attributes (from vertex shader)
// in vec2 fragTexCoord;
// in vec4 fragColor;

// Input uniform values
// uniform sampler2D texture0;
// uniform vec4 colDiffuse;

// Output fragment color
// out vec4 finalColor;

// NOTE: Add here your custom variables

void main()
{
    finalColor = vec4(1.0, 0.0, 0.0, 1.0);

    // Texel color fetching from texture sampler
    // vec4 texelColor = texture(texture0, fragTexCoord);

    // NOTE: Implement here your fragment shader code

    // final color is the color from the texture 
    //    times the tint color (colDiffuse)
    //    times the fragment color (interpolated vertex color)
    // finalColor = texelColor*colDiffuse*fragColor;
}