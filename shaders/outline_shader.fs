#version 430

layout(location = 0) uniform float treshold;
layout(location = 1) uniform float outlineWidth;
layout(location = 2) uniform vec4 mainColor;
layout(location = 3) uniform vec4 outlineColor;
in vec4 vertexColor;
in vec2 fragTexCoord;
in vec4 fragColor; 
out vec4 finalColor;

uniform sampler2D texture0;

// uniform vec4 WHITE = vec4(1., 1., 1., 0.);
uniform vec4 BLACK = vec4(0., 0., 0., 1.);

void main(){
	// treshold = 0.5;
	vec4 pos = gl_FragCoord / vec4(500., 500., 1., 1.);

	float currentColor = texture(texture0, fragTexCoord).r;

	float outlineAlpha = smoothstep(treshold - 0.05, treshold + 0.05, currentColor + outlineWidth);
	float alpha = smoothstep(treshold - 0.05, treshold + 0.05, currentColor);

	float dropShadowDistance = 0.05;

	float currentColorShadow = texture(texture0, fragTexCoord - vec2(dropShadowDistance)).r;
	float shadowAlpha = smoothstep(treshold - 0.05, treshold + 0.05, currentColorShadow);


	finalColor = mix(mainColor, outlineColor, alpha);
	finalColor = mix(BLACK, finalColor, outlineAlpha);
	finalColor.a = outlineAlpha + shadowAlpha;
	// finalColor.a = shadowAlpha;

}