# AIT-CG-3D-Ray-Stack

Implemented a real-time ray tracer that renders perfectly smooth refractive and reflective surfaces using a ray stack. Created as an extension of the [ray tracing project](https://github.com/trastopchin/AIT-CG-3D-Ray-Tracing) from my Computer Graphics course at the Aquincum Instute of Technology the fall of 2019 with professor László Szécsi.

This ray tracer is set up to render four glass spheres with different indices of refraction rotating about a checkerboard textured plane. The four spheres have indices of refraction of 1.3, 1.5, 1.7, and 1.9, and the scene is lit with a single point light and a single directional light.

<p align="center">
  <img src="/resources/screenshot01.png" alt="The four rotating glass spheres where the left-most sphere closest to the camera has an index of refraction of 1.3 and right-most sphere closest to the camera has an index of refraction of 1.5." width="400">
  <img src="/resources/screenshot02.png" alt="The four rotating glass spheres where the left-most sphere closest to the camera has an index of refraction of 1.7 and right-most sphere closest to the camera has an index of refraction of 1.9." width="400">
</p>

One should be able to download the [3D_ray_stack](https://github.com/trastopchin/AIT-CG-3D-Ray-Stack/tree/master/3D_ray_stack) folder and open up the [index.html](https://github.com/trastopchin/AIT-CG-3D-Ray-Stack/blob/master/3D_ray_stack/graphics/index.html) file in a web browser to see the project. To navigate the scene one can use the WASD keys to move around as well as click down and drag the mouse to change the camera's orientation. In the case of google chrome, one might have to open the browser with `open /Applications/Google\ Chrome.app --args --allow-file-access-from-files` in order to load images and textures properly. This project was built upon László Szécsi's starter code and class powerpoint slides.

Whereas there is still some JavaScript code that is making this project work, the majority of the ray tracing implementation takes place within the [trace-fs.glsl](https://github.com/trastopchin/AIT-CG-3D-Ray-Stack/blob/master/3D_ray_stack/graphics/js/shaders/trace-fs.glsl) fragment shader.

## Implementation Details

This ray tracer uses a stack to keep track of recursively spawned reflective and refracted light rays. We initialize the ray stack by pushing onto it the primary ray starting at the camera eye and headed towards the scene. The ray stack also keeps track of the "indirect lighting product," which for the first ray we initialize to vec3(1, 1, 1), and the recursive ray depth, which for the first ray we initialize to 1. Each iteration of the main ray casting loop pops a ray off the ray stack, processes it, and pushes any new possible recursively spawned reflected and refracted rays onto the stack.

Each iteration of the main ray casting loop starts by popping a ray of the ray stack. We then determine if the ray hits an object in the scene. If the ray does not intersect with a scene object, then that ray has hit the environment cubemap. So, that ray contributes the accumulated indirect lighting product multiplied by the color sampled from the environment cubemap to the fragment color of the pixel we are processing.

If the ray does intersect with a scene object, we first check if this is the first primary ray casted, and set the fragment depth according to the hit position in normalized device coordinates accordingly. After reading in the material properties, and flipping the surface normal and inverting the index of refraction based on which side of a quadric surface we are shading, we compute direct lambertian lighting by looping over each light in the scene, casting shadow rays, and testing for occluders. After computing the direct lighting, we have three cases. Either the material is only diffuse, diffuse and reflective, or reflective and refractive. In the first case we do nothing, and in the other two cases we start by computing the reflectance and transmittance of the surface using Schlick's approximation. If the material is reflective, we push a reflected ray onto the ray stack, multiplying the indirect lighting product by the reflectance. If the material is transmissive and reflective, we push a reflected ray onto the stack just as before, and push an additional refracted ray onto the stack, multiplying the indirect lighting product by the transmittance.

## Built With

* [WebGLMath](https://github.com/szecsi/WebGLMath) - László Szécsi's vector math library for WebGL programming.
