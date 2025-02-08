#version 430

in vec2 fragTexcoord;

uniform sampler2D tex;

out vec4 finalColor;

void main() {
    finalColor = texture(tex, fragTexcoord);
}