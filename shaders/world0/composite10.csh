#version 450 core

#define DOWNSAMPLE_LEVEL 0
const vec2 workGroupsRender = vec2(0.5f, 0.5f);

#include "/program/post/bloom/Downsample.comp"