/*
Tal Rastopchin
June 1, 2019

Adapted from Laszlo Szecsi's homework starter code and
powerpoint slide instructions.
*/
Shader.source[document.currentScript.src.split('js/shaders/')[1]] = `#version 300 es 
  precision highp float;

  out vec4 fragmentColor;
  in vec4 rayDir;

  // the properties of the material
  uniform struct {
  	samplerCube envTexture;
  } material;

  // the properties of the camera
  uniform struct {
    mat4 viewProjMatrix;  
    mat4 rayDirMatrix;
    vec3 position;
  } camera;

  // the properties of each clipped quadric object
  uniform struct {
    mat4 surface;
    mat4 clipper;
    vec3 baseColor;
    float reflection;
    float transmission;
    float mu;
    float checkerBoard;
  } clippedQuadrics[16];

  // the properties of each light object
  uniform struct {
    vec4 position;
    vec3 powerDensity;
  } lights[16];

  uniform struct {
    float time;
  } scene;

  // shading and illumination
  void computeDirectLighting(vec4 hitPos, vec3 normal, vec4 shadowStart, vec4 w, vec3 baseColor);
  vec3 fresnelReflectance(vec3 d, vec3 n, float mu);
  vec3 diffuseReflectance(vec3 normal, vec3 lightDir, vec3 powerDensity, vec3 baseColor);

  // ray-quadric intersection
  bool findBestHit(vec4 e, vec4 d, out float t, out int index);
  float intersectClippedQuadric(mat4 A, mat4 B,vec4 e, vec4 d);
  float intersectQuadric(mat4 A, vec4 e, vec4 d);
  vec3 quadricSurfaceNormal(vec4 point, mat4 quadric);

  // procedural texture
  vec3 checkerBoard(vec3 pos);

  // the number of clipped quadrics and lights processed
  const int NUM_CLIPPED_QUADRICS = 5;
  const int NUM_LIGHTS = 2;

  // the maximum number of recursive ray casts and stack stize
  const int MAX_RAYS = 16;
  const int MAX_RAY_DEPTH = 16;
  const int STACK_SIZE = 8;

  // helper constants
  const vec3 zero = vec3(0, 0, 0);
  const vec3 one = vec3(1, 1, 1);

  void main(void) {

    // allocate the ray stack
    vec4 eStack[STACK_SIZE];
    vec4 dStack[STACK_SIZE];
    vec4 wStack[STACK_SIZE];
    int top = 0;

    // push initial light ray onto the stack
    eStack[top] = vec4(camera.position, 1); // initial ray origin
    dStack[top] = vec4(normalize(rayDir.xyz), 0); // initial ray direction
    wStack[top] = vec4(1.0, 1.0, 1.0, 1.0);
    // w.rgb is the indirect lighting product and w.a is the light path recursive depth

    // process as many rays as the maximum amount of rays
    for (int rayIteration = 0; rayIteration < MAX_RAYS; rayIteration++) {

      // get current light ray from stack
      vec4 e = eStack[top];
      vec4 d = dStack[top];
      vec4 w = wStack[top];

      // determine if scene object ray intersection
      float t = 0.0;
      int index = 0;
      bool hit = findBestHit(e, d, t, index);

      // if scene object ray intersection
      if (hit) {

        // determine which object we hit, the hit position, and normal
        mat4 surface = clippedQuadrics[index].surface;
        vec4 hitPos = e + d * t;
        vec3 normal = quadricSurfaceNormal(hitPos, surface);

        // if first intersection, we set the fragment distance accordingly
        if (rayIteration == 0) {
          // computing depth from world space hitPos coordinates 
          vec4 ndcHit = hitPos * camera.viewProjMatrix;
          gl_FragDepth = ndcHit.z / ndcHit.w * 0.5 + 0.5;
        }

        // read in object material properties
        vec3 tex = one;
        if (clippedQuadrics[index].checkerBoard > 0.0) {
          tex = clippedQuadrics[index].checkerBoard * checkerBoard(hitPos.xyz);
        }
        vec3 baseColor = tex * clippedQuadrics[index].baseColor;
        float reflection = clippedQuadrics[index].reflection;
        float transmission = clippedQuadrics[index].transmission;
        float mu = clippedQuadrics[index].mu;

        // to handle both sides of the surface, flip normal towards incoming ray
        if(dot(normal, d.xyz) > 0.0) {
          normal = -normal;
        }
        else {
          // invert the refractive index as we exit a medium
          // honestly unsure why this happens here and not in the above
          // if statement. However, this get it to work. Maybe
          // my normals are all anti-parallel ?
          mu = 1.0 / mu;
        }

        // generate secondary shadow and refraction rays
        float delta = 0.0001;
        vec4 shadowStart = hitPos + vec4(delta * normal, 0);
        vec4 refracStart = hitPos - vec4(delta * normal, 0);

        // if not perfectly transmissive, compute contribution of direct lighting
        if (transmission < 1.0) {
        computeDirectLighting(hitPos, normal, shadowStart, w, baseColor);
        }
        top--; // remove current ray from top of stack as its processed

        // if the light path length is less than our max ray depth, we can cast deeper rays
        if (int(w.a) < MAX_RAY_DEPTH) {

          // compute reflectance and transmittance
          vec3 R = fresnelReflectance(d.xyz, normal, mu);
          vec3 T = one - R;

          // if is reflective and not transmittive and we can push onto the ray stack
          if (reflection > 0.0 && transmission == 0.0 && top < STACK_SIZE - 1) {

            // push a reflection ray onto the stack
            top++;
            eStack[top] = shadowStart;
            dStack[top] = vec4(reflect(d.xyz, normal), 0);

            // relfection's contribution to the indirect lighting product
            wStack[top].rgb = w.rgb * R;
            wStack[top].a = w.a + 1.0;
          }

          // if is reflective and transmittive and we can push onto the ray stack
          else if (reflection > 0.0 && transmission > 0.0 && top < STACK_SIZE - 1) {

            // push a reflection ray onto the stack
            top++;
            eStack[top] = shadowStart;
            dStack[top] = vec4(reflect(d.xyz, normal), 0);

            int ott = top; // ott : over-the-top

            // if there is space to push a refractive ray
            if (top < STACK_SIZE - 1) {
              vec3 refDir = refract(d.xyz, normal, mu);

              // check for total internal reflection
              if (dot(refDir, refDir) < 0.1) {
                R = one;
              }
              // otherwise, push a refracted ray to stack
              else {
                // update over-the-top
                ott++;

                // push a refraction ray onto the stack
                eStack[ott] = refracStart;
                dStack[ott] = vec4(normalize(refDir), 0);

                // refraction's contribution to the indirect lighting product w
                wStack[ott].rgb = w.rgb * T;
                wStack[ott].a = w.a + 1.0;
              }
            }

            // reflection's contribution to the indirect lighting product w
            wStack[top].rgb = w.rgb * R;
            wStack[top].a = w.a + 1.0;

            // set correct top of ray stack
            top = ott;
          }
          
        } // if we are not over the max ray depth
      } // if scene object ray intersection
      else {
        // if ray intersects no object, sample the environment texture
        fragmentColor.rgb += w.xyz * texture(material.envTexture, d.xyz).xyz;
        w.xyz *= 0.0;
        top--;
        gl_FragDepth = 0.9999999;
      } // if no scene object ray intersection

      // if top is out of bounds we have processed all rays (specified by MAX_RAYS and MAX_RAY_DEPTH)
      if (top < 0) break;
    }
  }

  /*
  Given a ray surface intersection point hitPos, a surface normal,
  normal, a shadow ray starting point shadowStart, the current
  indirect illumination product w, and a surface's base color,
  compute the contribution of point and directional lights using
  a diffuse reflectance model.
  */
  void computeDirectLighting(vec4 hitPos, vec3 normal, vec4 shadowStart, vec4 w, vec3 baseColor) {

    // light loop casts shadow rays and computes direct lambertian illumination
    for (int i = 0; i < NUM_LIGHTS; i++) {

      // compute per light illumination properties
      vec3 lightDiff = lights[i].position.xyz - hitPos.xyz / hitPos.w * lights[i].position.w;
      vec3 lightDir = normalize(lightDiff);
      float distanceSquared = dot(lightDiff, lightDiff);
      vec3 powerDensity = lights[i].powerDensity / distanceSquared;

      // cast shadow ray
      vec4 shadowDir = vec4(lightDir, 0);
      float bestShadowT = 0.0;
      int shadowIndex = 0;
      bool shadowRayHitSomething = findBestHit(shadowStart, shadowDir, bestShadowT, shadowIndex);

      // if ray didnt hit anything or no occluder
      if(!shadowRayHitSomething ||
       bestShadowT * lights[i].position.w > sqrt(dot(lightDiff, lightDiff))) {

        // compute direct lambertian illumination
        fragmentColor.rgb += w.xyz * diffuseReflectance(normal, lightDir, powerDensity, baseColor);
      }

      
    }
  }

  /*
  Given a ray direction d, a normal n, a refractive index mu computes the reflectance
 using the fresnel approximation. Returns the reflectance; transmittance is 1 - reflectance.
  */
  vec3 fresnelReflectance(vec3 d, vec3 n, float mu) {
    float R0 = ((mu - 1.0) * (mu - 1.0)) / ((mu + 1.0) * (mu + 1.0));
    float alpha = dot(-d, n);
    float val = R0 + (1.0 - R0) * pow((1.0 - cos(alpha)), 5.0);
    return vec3(val, val, val);
  }

  /*
  Lambertian diffuse reflection model. Given a surface normal, a
  vector pointing from the surface point to the light position
  lightdir, an RGB power density, and a surface base color, compute
  the lambertian reflectance.
  */
  vec3 diffuseReflectance(vec3 normal, vec3 lightDir, vec3 powerDensity, vec3 baseColor) {
    float cosa = clamp(dot(lightDir, normal), 0.0, 1.0);
    vec3 diffuse = cosa * powerDensity * baseColor;
    return diffuse;
  }

  /*
  Determine whether or not a given ray parameterized by vectors e
  and d intersects with the clipped quadrics passed in through the
  clippedQuadrics uniform. Returns a boolean depending on whether
  or not such an intersection is found. If such an intersection is
  found, determine which clipped quadric intersection is closest
  to the ray start and accordingly set the ray parameter t and
  clipped quadric index index.
  */
  bool findBestHit(vec4 e, vec4 d, out float t, out int index) {
    // hitPos represents whether or not an intersection has been found
    bool hitPos = false;

    // initialize our bestT and bestIndex variables
    float bestT = 0.0;
    int bestIndex = 0;

    // for each clipped quadric in our uniform array
    for (int i = 0; i < NUM_CLIPPED_QUADRICS; i++) {
      mat4 surface = clippedQuadrics[i].surface;
      mat4 clipper = clippedQuadrics[i].clipper;

      float tCurrent = intersectClippedQuadric(surface, clipper, e, d);
      // t negative -> no intersection
      if (tCurrent < 0.0) {
        continue;
      }
      // t positive and first found intersection
      else if (hitPos == false) {
        hitPos = true;
        bestT = tCurrent;
        bestIndex = i;
      }
      // t positive and closer than previously found intersection
      else if (tCurrent < bestT) {
        hitPos = true;
        bestT = tCurrent;
        bestIndex = i;
      }
    }

    // if hitPos set the t and index out parameters accordingly
    if (hitPos) {
      t = bestT;
      index =  bestIndex;
    }

    return hitPos;
  }

  /*
  Determine whether or not a given ray parameterized by vectors e
  and d intersects with a clipped quadric defined by the quadratic
  coefficient matrices A and B, where A represents the surface and
  B represents the clipper. If there is no intersection returns a
  negative value, namely -1.0. If there is an intersection(s),
  determine if they are within the bounds of the clipping quadric
  and then return the closest possible intersection ray parameter.
  */
  float intersectClippedQuadric(mat4 A, mat4 B, vec4 e, vec4 d) {
    // compute quadratic coefficients a, b, and c
    float a = dot(d * A, d);
    float b = dot(d * A, e) + dot(e * A, d);
    float c = dot(e * A, e);

    float discriminant = b*b - 4.0*a*c;

    // if no intersections -> t negative
    if (discriminant < 0.0) {
      return -1.0;
    }

    // if intersections
    float t1 = (-b + sqrt(discriminant)) / 2.0 / a;
    float t2 = (-b - sqrt(discriminant)) / 2.0 / a;

    // determine intersection points
    vec4 r1 = e + d * t1;
    vec4 r2 = e + d * t2;

    // determine if points lie within the clipper
    if (dot(r1 * B, r1) > 0.0) {
      t1 = -1.0;
    }
    if (dot(r2 * B, r2) > 0.0) {
      t2 = -1.0;
    }

    // return lesser of t1 and t2
    return (t1<0.0)?t2:((t2<0.0)?t1:min(t1, t2));
  }

  /*
  Determine whether or not a given ray parameterized by vectors e
  and d intersects with a clipped quadric defined by the quadratic
  coefficient matrix A. If there is no intersection returns a 
  negative value, namely -1.0. If there is an intersection(s),
  return the closest possible intersection ray parameter.
  */
  float intersectQuadric(mat4 A, vec4 e, vec4 d) {
    // compute quadratic coefficients a, b, and c
    float a = dot(d * A, d);
    float b = dot(d * A, e) + dot(e * A, d);
    float c = dot(e * A, e);

    float discriminant = b*b - 4.0*a*c;

    // if no intersections -> t negative
    if (discriminant < 0.0) {
      return -1.0;
    }

    // if intersections
    float t1 = (-b + sqrt(discriminant)) / 2.0 / a;
    float t2 = (-b - sqrt(discriminant)) / 2.0 / a;

    // return lesser of t1 and t2
    return (t1<0.0)?t2:((t2<0.0)?t1:min(t1, t2));
  }

  /*
  Determines the surface normal at a given point on a quadratic
  surface defined by the coefficent matrix surface.
  */
  vec3 quadricSurfaceNormal(vec4 point, mat4 surface) {
    return normalize((point * surface + surface * point).xyz);
  }

  // a simple checkerBoard texture
  vec3 checkerBoard(vec3 pos) {
    if (mod(pos.x, 4.0) < 2.0 && mod(pos.z, 4.0) < 2.0 || mod(pos.x, 4.0) > 2.0 && mod(pos.z, 4.0) > 2.0 ) {
      return one;
    }
    else {
      return 0.5 * one;
    }

  }
`;