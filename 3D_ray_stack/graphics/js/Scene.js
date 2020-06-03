/*
Tal Rastopchin
December 1, 2019

Adapted from Laszlo Szecsi's homework starter code and
powerpoint slide instructions.
*/
"use strict";
/* exported Scene */
class Scene extends UniformProvider {
  constructor(gl) {
    super("scene");
    this.programs = [];
    this.gameObjects = [];

    this.fsTextured = new Shader(gl, gl.FRAGMENT_SHADER, "textured-fs.glsl");
    this.vsTextured = new Shader(gl, gl.VERTEX_SHADER, "textured-vs.glsl");    
    this.programs.push( 
    	this.texturedProgram = new TexturedProgram(gl, this.vsTextured, this.fsTextured));

    this.vsQuad = new Shader(gl, gl.VERTEX_SHADER, "quad-vs.glsl");    
    this.fsTrace = new Shader(gl, gl.FRAGMENT_SHADER, "trace-fs.glsl");
    this.fsShow = new Shader(gl, gl.FRAGMENT_SHADER, "show-fs.glsl");
    this.programs.push( 
    	this.traceProgram = new TexturedProgram(gl, this.vsQuad, this.fsTrace));
    this.programs.push( 
      this.showProgram = new TexturedProgram(gl, this.vsQuad, this.fsShow));

    this.texturedQuadGeometry = new TexturedQuadGeometry(gl);    

    this.timeAtFirstFrame = new Date().getTime();
    this.timeAtLastFrame = this.timeAtFirstFrame;

    this.traceMaterial = new Material(this.traceProgram);
    this.envTexture = new TextureCube(gl, [
      "media/fnx.png",
      "media/fx.png",
      "media/fy.png",
      "media/fny.png",
      "media/fz.png",
      "media/fnz.png",]
      );
    this.traceMaterial.envTexture.set(this.envTexture);
    this.traceMesh = new Mesh(this.traceMaterial, this.texturedQuadGeometry);

    this.traceQuad = new GameObject(this.traceMesh);
    this.gameObjects.push(this.traceQuad);

    this.camera = new PerspectiveCamera(...this.programs); 
    this.camera.position.set(0, 1.5, 6);
    this.camera.pitch = -0.3;
    this.camera.update();

    // scene definition
    this.clippedQuadrics = [];
    this.lights = [];

    // create a floor plane
    this.woodenFloor = this.createClippedQuadric();
    this.woodenFloor.makePlane();
    this.woodenFloor.transform(new Mat4().translate(0, -2, 0));
    this.woodenFloor.checkerBoard = 1;

    // create glass spheres
    this.glassSpheres = [];
    for (let i = 0; i < 4; i++) {
        const glass = this.createGlass(2 * Math.PI / 4 * i);
        glass.mu = 1.3 + i * 0.2;
        this.glassSpheres.push(glass);
    }

    // create one directional light
    this.dir1 = this.createLight();
    this.dir1.position.set(1, 1, 1, 0);
    this.dir1.powerDensity.set(4, 4, 4);

    // create one point light
    this.point1 = this.createLight();
    this.point1.powerDensity.set(16, 16, 16);
    this.point1.position.set(0, 8, 0);

    this.addComponentsAndGatherUniforms(...this.programs);

    gl.enable(gl.DEPTH_TEST);
  }

  createGlass(theta) {
    const glass = this.createClippedQuadric();
    glass.reflection = 1;
    glass.transmission = 1;
    glass.theta = theta;
    return glass;
  }

  transformUnitSphere(quadric, x, y, z) {
    quadric.makeUnitSphere();
    quadric.transform(new Mat4().translate(x, y, z));
  }

  createClippedQuadric() {
    const clippedQuadric = new ClippedQuadric(this.clippedQuadrics.length, ...this.programs);
    clippedQuadric.baseColor.set(1, 1, 1);
    clippedQuadric.reflection = 0 ;
    clippedQuadric.transmission = 0;
    clippedQuadric.mu = 1.5;
    clippedQuadric.checkerBoard = 0;
    this.clippedQuadrics.push(clippedQuadric);
    return clippedQuadric;
  }

  createLight() {
    const light = new Light(this.lights.length, ...this.programs);
    this.lights.push(light);
    return light;
  }

  resize(gl, canvas) {
    gl.viewport(0, 0, canvas.width, canvas.height);
    this.camera.setAspectRatio(canvas.width / canvas.height);
  }

  update(gl, keysPressed) {
    //jshint bitwise:false
    //jshint unused:false
    const timeAtThisFrame = new Date().getTime();
    const dt = (timeAtThisFrame - this.timeAtLastFrame) / 1000.0;
    const t = (timeAtThisFrame - this.timeAtFirstFrame) / 1000.0; 
    this.timeAtLastFrame = timeAtThisFrame;
    this.time = t;

    // rotate the glass spheres
    for (const glassSphere of this.glassSpheres) {
        const x = 2 * Math.cos(t + glassSphere.theta);
        const y = 0;
        const z = 2 * Math.sin(t + glassSphere.theta);
        this.transformUnitSphere(glassSphere, x, y, z);
    }

    // clear the screen
    gl.clearColor(0.3, 0.0, 0.3, 1.0);
    gl.clearDepth(1.0);
    gl.clear(gl.COLOR_BUFFER_BIT | gl.DEPTH_BUFFER_BIT);

    this.camera.move(dt, keysPressed);

    for(const gameObject of this.gameObjects) {
        gameObject.update();
    }
    for(const gameObject of this.gameObjects) {
        gameObject.draw(this, this.camera, ...this.clippedQuadrics, ...this.lights);
    }
  }
}
