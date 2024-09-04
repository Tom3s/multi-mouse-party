#version 430

// layout(location = 0) uniform float treshold;
// layout(location = 1) uniform float outlineWidth;
// layout(location = 2) uniform vec4 mainColor;
layout(location = 3) uniform vec4 outline_color;
in vec4 vertexColor;
in vec2 fragTexCoord;
in vec4 fragColor; 
out vec4 finalColor;

uniform sampler2D texture0;

// uniform vec4 WHITE = vec4(1., 1., 1., 0.);
uniform vec4 BLACK = vec4(0., 0., 0., 1.);

void main(){

	float outline_distance = 0.1;

	vec2 up = fragTexCoord + vec2(0.0, -outline_distance);
	// vec2 down = fragTexCoord + vec2(0.0, +outline_distance);
	// vec2 left = fragTexCoord + vec2(-outline_distance, 0.0);
	vec2 right = fragTexCoord + vec2(+outline_distance, 0.0);

	// vec2 up_right = up + right;
	// vec2 up_left = up + left;
	// vec2 down_right = down + right;
	// vec2 down_left = down + left;

	finalColor = texture(texture0, fragTexCoord) * fragColor;

	if (finalColor.a > 0.0) {
		finalColor = mix(finalColor, outline_color, 1.0 - finalColor.a);
		finalColor.a = 1.0;
		return;
	}

	// float outline = max(
	// 	texture(texture0, fragTexCoord + up).a,
	// 	texture(texture0, fragTexCoord - up).a,
	// 	texture(texture0, fragTexCoord + right).a,
	// 	texture(texture0, fragTexCoord - right).a,
	// 	texture(texture0, fragTexCoord + up + right).a,
	// 	texture(texture0, fragTexCoord - up - right).a,
	// 	texture(texture0, fragTexCoord - up + right).a,
	// 	texture(texture0, fragTexCoord + up - right).a
	// );
	float outline = texture(texture0, fragTexCoord + up).a;

	outline = max(outline, texture(texture0, fragTexCoord - up).a);
	outline = max(outline, texture(texture0, fragTexCoord + right).a);
	outline = max(outline, texture(texture0, fragTexCoord - right).a);
	outline = max(outline, texture(texture0, fragTexCoord + up + right).a);
	outline = max(outline, texture(texture0, fragTexCoord - up - right).a);
	outline = max(outline, texture(texture0, fragTexCoord - up + right).a);
	outline = max(outline, texture(texture0, fragTexCoord + up - right).a);
	


	finalColor = vec4(outline_color.rgb, outline);

}