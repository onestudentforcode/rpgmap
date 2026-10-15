shader_type canvas_item;
// P8.7 trial: material sampling remains in logical ground space.
uniform vec2 ground_view_scale = vec2(1.0);
uniform sampler2D shore_mask : filter_nearest, repeat_disable;
uniform vec2 grid_origin = vec2(-4.0,0.0);
uniform vec2 grid_size = vec2(32.0,22.0);
uniform vec4 grass_tone : source_color = vec4(0.5804,0.6784,0.4980,1.0);
uniform vec4 dirt_tone : source_color = vec4(0.6902,0.5961,0.4784,1.0);
uniform vec4 stone_tone : source_color = vec4(0.6627,0.6863,0.6196,1.0);
varying vec2 ground_position;
vec4 cell_data(vec2 cell) {
    vec2 local=cell-grid_origin;
    if (any(lessThan(local,vec2(0.0))) || any(greaterThanEqual(local,grid_size))) return vec4(0.0);
    return texture(shore_mask,(local+0.5)/grid_size);
}
void vertex() {ground_position=(MODEL_MATRIX*vec4(VERTEX,0.0,1.0)).xy / ground_view_scale;}
void fragment() {
    vec2 cell=floor(ground_position/64.0);
    vec4 current=cell_data(cell);
    float distance_to_edge=999.0;
    float kind=current.b;
    for(int y=-1;y<=1;y++){
        for(int x=-1;x<=1;x++){
            vec2 other=cell+vec2(float(x),float(y));
            vec4 data=cell_data(other);
            if(data.g>0.5 && abs(data.r-current.r)>0.5){
                vec2 delta=max(max(other*64.0-ground_position,ground_position-(other+1.0)*64.0),vec2(0.0));
                float candidate=length(delta);
                if(candidate<distance_to_edge){distance_to_edge=candidate;if(current.r>0.5)kind=data.b;}
            }
        }
    }
    float d=distance_to_edge*(current.r>0.5?1.0:-1.0);
    d+=sin(ground_position.x/55.0+ground_position.y/47.0)*1.35+sin(ground_position.x/19.0-ground_position.y/23.0)*0.55;
    float aa=max(fwidth(d),0.65);
    float land=1.0-smoothstep(-aa,aa,d);
    float wet=(1.0-smoothstep(1.0,5.5,d))*smoothstep(-2.5,0.5,d);
    float shadow=(1.0-smoothstep(4.5,15.0,d))*smoothstep(0.0,4.0,d)*0.27;
    float wave=(1.0-smoothstep(0.45,1.4,abs(d-18.0)))*0.19;
    vec3 tone=grass_tone.rgb;
    if(kind>0.12 && kind<0.37)tone=dirt_tone.rgb;
    if(kind>0.37 && kind<0.62)tone=stone_tone.rgb;
    float coverage=max(land,wet*0.8);
    vec3 color=mix(vec3(0.23,0.39,0.33),mix(tone,vec3(0.57,0.57,0.40),wet*0.45),coverage/max(0.001,coverage+shadow));
    float alpha=max(coverage,shadow);
    color=mix(color,vec3(0.79,0.87,0.78),wave/max(0.001,alpha+wave));
    COLOR=vec4(color,max(alpha,wave)*smoothstep(-12.0,-7.0,d)*float(current.g>0.5)*float(distance_to_edge<24.0));
}
