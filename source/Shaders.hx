package;

import flixel.system.FlxAssets.FlxShader;
import openfl.display.BitmapData;
import openfl.display.Shader;
import openfl.display.ShaderInput;
import openfl.utils.Assets;
import flixel.FlxG;
import openfl.Lib;

using StringTools;

typedef ShaderEffect =
{
	var shader:Dynamic;
}

class BuildingEffect
{
	public var shader:BuildingShader = new BuildingShader();

	public function new()
	{
		shader.alphaShit.value = [0];
	}

	public function addAlpha(alpha:Float)
	{
		trace(shader.alphaShit.value[0]);
		shader.alphaShit.value[0] += alpha;
	}

	public function setAlpha(alpha:Float)
	{
		shader.alphaShit.value[0] = alpha;
	}
}

class BuildingShader extends FlxShader
{
	@:glFragmentSource('
    #pragma header
    uniform float alphaShit;
    void main()
    {

      vec4 color = flixel_texture2D(bitmap,openfl_TextureCoordv);
      if (color.a > 0.0)
        color-=alphaShit;

      gl_FragColor = color;
    }
  ')
	public function new()
	{
		super();
	}
}

class ChromaticAberrationShader extends FlxShader
{
	@:glFragmentSource('
		#pragma header

		uniform float rOffset;
		uniform float gOffset;
		uniform float bOffset;

		void main()
		{
			#pragma body

			vec4 col1 = texture2D(bitmap, openfl_TextureCoordv.st - vec2(rOffset, 0.0));
			vec4 col2 = texture2D(bitmap, openfl_TextureCoordv.st - vec2(gOffset, 0.0));
			vec4 col3 = texture2D(bitmap, openfl_TextureCoordv.st - vec2(bOffset, 0.0));
			vec4 toUse = texture2D(bitmap, openfl_TextureCoordv);
			toUse.r = col1.r;
			toUse.g = col2.g;
			toUse.b = col3.b;
			//float someshit = col4.r + col4.g + col4.b;

			gl_FragColor = toUse;
		}')
	public function new()
	{
		super();
	}
}

class ChromaticAberrationEffect extends Effect
{
	public var shader:ChromaticAberrationShader;

	public function new(offset:Float = 0.00)
	{
		shader = new ChromaticAberrationShader();
		shader.rOffset.value = [offset];
		shader.gOffset.value = [0.0];
		shader.bOffset.value = [-offset];
	}

	public function setChrome(chromeOffset:Float):Void
	{
		shader.rOffset.value = [chromeOffset];
		shader.gOffset.value = [0.0];
		shader.bOffset.value = [chromeOffset * -1];
	}
}

class ScanlineEffect extends Effect
{
	public var shader:Scanline;

	public function new (lockAlpha)
	{
		shader = new Scanline();
		shader.lockAlpha.value = [lockAlpha];
	}
}

class Scanline extends FlxShader
{
	@:glFragmentSource('
		#pragma header
		const float scale = 1.0;
		uniform bool lockAlpha;
		void main()
		{
			#pragma body
			if (mod(floor(openfl_TextureCoordv.y * openfl_TextureSize.y / scale), 2.0) == 0.0 ){
				float bitch = 1.0;
	
				vec4 texColor = texture2D(bitmap, openfl_TextureCoordv);
				if (lockAlpha) bitch = texColor.a;
				gl_FragColor = vec4(0.0, 0.0, 0.0, bitch);
			}else{
				gl_FragColor = texture2D(bitmap, openfl_TextureCoordv);
			}
		}')
	public function new()
	{
		super();
	}
}

class TiltshiftEffect extends Effect
{
	public var shader:Tiltshift;

	public function new (blurAmount:Float, center:Float)
	{
		shader = new Tiltshift();
		shader.bluramount.value = [blurAmount];
		shader.center.value = [center];
	}
}

class Tiltshift extends FlxShader
{
	@:glFragmentSource('
		#pragma header

		// Modified version of a tilt shift shader from Martin Jonasson (http://grapefrukt.com/)
		// Read http://notes.underscorediscovery.com/ for context on shaders and this file
		// License : MIT
		 
			/*
				Take note that blurring in a single pass (the two for loops below) is more expensive than separating
				the x and the y blur into different passes. This was used where bleeding edge performance
				was not crucial and is to illustrate a point. 
		 
				The reason two passes is cheaper? 
				   texture2D is a fairly high cost call, sampling a texture.
		 
				   So, in a single pass, like below, there are 3 steps, per x and y. 
		 
				   That means a total of 9 "taps", it touches the texture to sample 9 times.
		 
				   Now imagine we apply this to some geometry, that is equal to 16 pixels on screen (tiny)
				   (16 * 16) * 9 = 2304 samples taken, for width * height number of pixels, * 9 taps
				   Now, if you split them up, it becomes 3 for x, and 3 for y, a total of 6 taps
				   (16 * 16) * 6 = 1536 samples
			
				   That\'s on a *tiny* sprite, let\'s scale that up to 128x128 sprite...
				   (128 * 128) * 9 = 147,456
				   (128 * 128) * 6 =  98,304
		 
				   That\'s 33.33..% cheaper for splitting them up.
				   That\'s with 3 steps, with higher steps (more taps per pass...)
		 
				   A really smooth, 6 steps, 6*6 = 36 taps for one pass, 12 taps for two pass
				   You will notice, the curve is not linear, at 12 steps it\'s 144 vs 24 taps
				   It becomes orders of magnitude slower to do single pass!
				   Therefore, you split them up into two passes, one for x, one for y.
			*/
		 
		// I am hardcoding the constants like a jerk
			
		uniform float bluramount;
		uniform float center;
		const float stepSize    = 0.004;
		const float steps       = 3.0;
		 
		const float minOffs     = (float(steps-1.0)) / -2.0;
		const float maxOffs     = (float(steps-1.0)) / +2.0;
		 
		void main() {
			#pragma body
			float amount;
			vec4 blurred;
				
			// Work out how much to blur based on the mid point 
			amount = pow((openfl_TextureCoordv.y * center) * 2.0 - 1.0, 2.0) * bluramount;
				
			// This is the accumulation of color from the surrounding pixels in the texture
			blurred = vec4(0.0, 0.0, 0.0, 1.0);
				
			// From minimum offset to maximum offset
			for (float offsX = minOffs; offsX <= maxOffs; ++offsX) {
				for (float offsY = minOffs; offsY <= maxOffs; ++offsY) {
		 
					// copy the coord so we can mess with it
					vec2 temp_tcoord = openfl_TextureCoordv.xy;
		 
					//work out which uv we want to sample now
					temp_tcoord.x += offsX * amount * stepSize;
					temp_tcoord.y += offsY * amount * stepSize;
		 
					// accumulate the sample 
					blurred += texture2D(bitmap, temp_tcoord);
				}
			} 
				
			// because we are doing an average, we divide by the amount (x AND y, hence steps * steps)
			blurred /= float(steps * steps);
		 
			// return the final blurred color
			gl_FragColor = blurred;
		}')
	public function new()
	{
		super();
	}
}

class GreyscaleEffect extends Effect
{
	public var shader:GreyscaleShader = new GreyscaleShader();

	public function new()
	{
	}
}

class GreyscaleShader extends FlxShader
{
	@:glFragmentSource('
	#pragma header
	void main() {
		vec4 color = texture2D(bitmap, openfl_TextureCoordv);
		float gray = dot(color.rgb, vec3(0.299, 0.587, 0.114));
		gl_FragColor = vec4(vec3(gray), color.a);
	}
	
	
	')
	public function new()
	{
		super();
	}
}

class GrainEffect extends Effect
{
	public var shader:Grain;

	public function new (grainsize, lumamount, lockAlpha, coloramount)
	{
		shader = new Grain();
		shader.lumamount.value = [lumamount];
		shader.grainsize.value = [grainsize];
		shader.lockAlpha.value = [lockAlpha];
		shader.coloramount.value = [coloramount];
		shader.uTime.value = [FlxG.random.float(0, 8)];
		PlayState.instance.shaderUpdates.push(update);
	}

	public function update(elapsed)
	{
		shader.uTime.value[0] += elapsed;
	}
}

class Grain extends FlxShader
{
	@:glFragmentSource('
		#pragma header

		/*
		Film Grain post-process shader v1.1
		Martins Upitis (martinsh) devlog-martinsh.blogspot.com
		2013

		--------------------------
		This work is licensed under a Creative Commons Attribution 3.0 Unported License.
		So you are free to share, modify and adapt it for your needs, and even use it for commercial use.
		I would also love to hear about a project you are using it.

		Have fun,
		Martins
		--------------------------

		Perlin noise shader by toneburst:
		http://machinesdontcare.wordpress.com/2009/06/25/3d-perlin-noise-sphere-vertex-shader-sourcecode/
		*/
		uniform float uTime;

		const float permTexUnit = 1.0/256.0;        // Perm texture texel-size
		const float permTexUnitHalf = 0.5/256.0;    // Half perm texture texel-size

		float width = 0.0;
		float height = 0.0;

		const float grainamount = 0.05; //grain amount
		bool colored = false; //colored noise?
		uniform float coloramount;
		uniform float grainsize; //grain particle size (1.5 - 2.5)
		uniform float lumamount; //
	uniform bool lockAlpha;

		//a random texture generator, but you can also use a pre-computed perturbation texture
	
		vec4 rnm(in vec2 tc)
		{
			float noise =  sin(dot(tc + vec2(uTime,uTime),vec2(12.9898,78.233))) * 43758.5453;

			float noiseR =  fract(noise)*2.0-1.0;
			float noiseG =  fract(noise*1.2154)*2.0-1.0;
			float noiseB =  fract(noise * 1.3453) * 2.0 - 1.0;
			
				
			float noiseA =  (fract(noise * 1.3647) * 2.0 - 1.0);

			return vec4(noiseR,noiseG,noiseB,noiseA);
		}

		float fade(in float t) {
			return t*t*t*(t*(t*6.0-15.0)+10.0);
		}

		float pnoise3D(in vec3 p)
		{
			vec3 pi = permTexUnit*floor(p)+permTexUnitHalf; // Integer part, scaled so +1 moves permTexUnit texel
			// and offset 1/2 texel to sample texel centers
			vec3 pf = fract(p);     // Fractional part for interpolation

			// Noise contributions from (x=0, y=0), z=0 and z=1
			float perm00 = rnm(pi.xy).a ;
			vec3  grad000 = rnm(vec2(perm00, pi.z)).rgb * 4.0 - 1.0;
			float n000 = dot(grad000, pf);
			vec3  grad001 = rnm(vec2(perm00, pi.z + permTexUnit)).rgb * 4.0 - 1.0;
			float n001 = dot(grad001, pf - vec3(0.0, 0.0, 1.0));

			// Noise contributions from (x=0, y=1), z=0 and z=1
			float perm01 = rnm(pi.xy + vec2(0.0, permTexUnit)).a ;
			vec3  grad010 = rnm(vec2(perm01, pi.z)).rgb * 4.0 - 1.0;
			float n010 = dot(grad010, pf - vec3(0.0, 1.0, 0.0));
			vec3  grad011 = rnm(vec2(perm01, pi.z + permTexUnit)).rgb * 4.0 - 1.0;
			float n011 = dot(grad011, pf - vec3(0.0, 1.0, 1.0));

			// Noise contributions from (x=1, y=0), z=0 and z=1
			float perm10 = rnm(pi.xy + vec2(permTexUnit, 0.0)).a ;
			vec3  grad100 = rnm(vec2(perm10, pi.z)).rgb * 4.0 - 1.0;
			float n100 = dot(grad100, pf - vec3(1.0, 0.0, 0.0));
			vec3  grad101 = rnm(vec2(perm10, pi.z + permTexUnit)).rgb * 4.0 - 1.0;
			float n101 = dot(grad101, pf - vec3(1.0, 0.0, 1.0));

			// Noise contributions from (x=1, y=1), z=0 and z=1
			float perm11 = rnm(pi.xy + vec2(permTexUnit, permTexUnit)).a ;
			vec3  grad110 = rnm(vec2(perm11, pi.z)).rgb * 4.0 - 1.0;
			float n110 = dot(grad110, pf - vec3(1.0, 1.0, 0.0));
			vec3  grad111 = rnm(vec2(perm11, pi.z + permTexUnit)).rgb * 4.0 - 1.0;
			float n111 = dot(grad111, pf - vec3(1.0, 1.0, 1.0));

			// Blend contributions along x
			vec4 n_x = mix(vec4(n000, n001, n010, n011), vec4(n100, n101, n110, n111), fade(pf.x));

			// Blend contributions along y
			vec2 n_xy = mix(n_x.xy, n_x.zw, fade(pf.y));

			// Blend contributions along z
			float n_xyz = mix(n_xy.x, n_xy.y, fade(pf.z));

			// We are done, return the final noise value.
			return n_xyz;
		}

		//2d coordinate orientation thing
		vec2 coordRot(in vec2 tc, in float angle)
		{
			float aspect = width/height;
			float rotX = ((tc.x*2.0-1.0)*aspect*cos(angle)) - ((tc.y*2.0-1.0)*sin(angle));
			float rotY = ((tc.y*2.0-1.0)*cos(angle)) + ((tc.x*2.0-1.0)*aspect*sin(angle));
			rotX = ((rotX/aspect)*0.5+0.5);
			rotY = rotY*0.5+0.5;
			return vec2(rotX,rotY);
		}

		void main()
		{
			#pragma body
			width = openfl_TextureSize.x;
			height = openfl_TextureSize.y;

			vec2 texCoord = openfl_TextureCoordv.st;

			vec3 rotOffset = vec3(1.425,3.892,5.835); //rotation offset values
			vec2 rotCoordsR = coordRot(texCoord, uTime + rotOffset.x);
			vec3 noise = vec3(pnoise3D(vec3(rotCoordsR*vec2(width/grainsize,height/grainsize),0.0)));

			if (colored)
			{
				vec2 rotCoordsG = coordRot(texCoord, uTime + rotOffset.y);
				vec2 rotCoordsB = coordRot(texCoord, uTime + rotOffset.z);
				noise.g = mix(noise.r,pnoise3D(vec3(rotCoordsG*vec2(width/grainsize,height/grainsize),1.0)),coloramount);
				noise.b = mix(noise.r,pnoise3D(vec3(rotCoordsB*vec2(width/grainsize,height/grainsize),2.0)),coloramount);
			}

			vec3 col = texture2D(bitmap, openfl_TextureCoordv).rgb;

			//noisiness response curve based on scene luminance
			vec3 lumcoeff = vec3(0.299,0.587,0.114);
			float luminance = mix(0.0,dot(col, lumcoeff),lumamount);
			float lum = smoothstep(0.2,0.0,luminance);
			lum += luminance;


			noise = mix(noise,vec3(0.0),pow(lum,4.0));
			col = col+noise*grainamount;

				float bitch = 1.0;
			vec4 texColor = texture2D(bitmap, openfl_TextureCoordv);
				if (lockAlpha) bitch = texColor.a;
			gl_FragColor =  vec4(col,bitch);
		}')
	public function new()
	{
		super();
	}
}

class VCRDistortionEffect extends Effect
{
	public var shader:VCRDistortionShader;

	public function new(glitchFactor:Float, distortion:Bool = true, perspectiveOn:Bool = true, vignetteMoving:Bool = true, rgb:Bool = true, noise:Bool = true)
	{
		shader = new VCRDistortionShader();
		shader.iTime.value = [0];
		shader.vignetteOn.value = [true];
		shader.perspectiveOn.value = [perspectiveOn];
		shader.distortionOn.value = [distortion];
		shader.scanlinesOn.value = [true];
		shader.vignetteMoving.value = [vignetteMoving];
		shader.glitchModifier.value = [glitchFactor];
		shader.rgb.value = [rgb];
		shader.noise.value = [noise];
		shader.iResolution.value = [Lib.current.stage.stageWidth, Lib.current.stage.stageHeight];
		// var noise = Assets.getBitmapData(Paths.image("noise2"));
		// shader.noiseTex.input = noise;
		PlayState.instance.shaderUpdates.push(update);
	}

	public function update(elapsed:Float)
	{
		shader.iTime.value[0] += elapsed;
		shader.iResolution.value = [Lib.current.stage.stageWidth, Lib.current.stage.stageHeight];
	}

	public function setVignette(state:Bool)
	{
		shader.vignetteOn.value[0] = state;
	}

	public function setPerspective(state:Bool)
	{
		shader.perspectiveOn.value[0] = state;
	}

	public function setGlitchModifier(modifier:Float)
	{
		shader.glitchModifier.value[0] = modifier;
	}

	public function setDistortion(state:Bool)
	{
		shader.distortionOn.value[0] = state;
	}

	public function setScanlines(state:Bool)
	{
		shader.scanlinesOn.value[0] = state;
	}

	public function setVignetteMoving(state:Bool)
	{
		shader.vignetteMoving.value[0] = state;
	}

	public function setRGB(state:Bool)
	{
		shader.rgb.value[0] = state;
	}

	public function setNoise(state:Bool)
	{
		shader.noise.value[0] = state;
	}
}

class VCRDistortionShader extends FlxShader // https://www.shadertoy.com/view/ldjGzV and https://www.shadertoy.com/view/Ms23DR and https://www.shadertoy.com/view/MsXGD4 and https://www.shadertoy.com/view/Xtccz4
{

	@:glFragmentSource('
    #pragma header

    uniform float iTime;
    uniform bool vignetteOn;
    uniform bool perspectiveOn;
    uniform bool distortionOn;
    uniform bool scanlinesOn;
    uniform bool vignetteMoving;
    uniform bool rgb;
    uniform bool noise;
   // uniform sampler2D noiseTex;
    uniform float glitchModifier;
    uniform vec3 iResolution;

    float onOff(float a, float b, float c)
    {
    	return step(c, sin(iTime + a*cos(iTime*b)));
    }

    float ramp(float y, float start, float end)
    {
    	float inside = step(start,y) - step(end,y);
    	float fact = (y-start)/(end-start)*inside;
    	return (1.0-fact) * inside;

    }

    vec4 getVideo(vec2 uv)
      {
      	vec2 look = uv;
        if(distortionOn){
        	float window = 1.0/(1.0+20.0*(look.y-mod(iTime/4.0,1.0))*(look.y-mod(iTime/4.0,1.0)));
        	look.x = look.x + (sin(look.y*10.0 + iTime)/50.0*onOff(4.0,4.0,0.3)*(1.0+cos(iTime*80.0))*window)*(glitchModifier*2.0);
        	float vShift = 0.4*onOff(2.0,3.0,0.9)*(sin(iTime)*sin(iTime*20.0) +
        										 (0.5 + 0.1*sin(iTime*200.0)*cos(iTime)));
        	look.y = mod(look.y + vShift*glitchModifier, 1.0);
        }
      	vec4 video = flixel_texture2D(bitmap,look);

      	return video;
      }

    vec2 screenDistort(vec2 uv)
    {
      if(perspectiveOn){
        uv = (uv - 0.5) * 2.0;
      	uv *= 1.1;
      	uv.x *= 1.0 + pow((abs(uv.y) / 5.0), 2.0);
      	uv.y *= 1.0 + pow((abs(uv.x) / 4.0), 2.0);
      	uv  = (uv / 2.0) + 0.5;
      	uv =  uv *0.92 + 0.04;
      	return uv;
      }
    	return uv;
    }
    float random(vec2 uv)
    {
     	return fract(sin(dot(uv, vec2(15.5151, 42.2561))) * 12341.14122 * sin(iTime * 0.03));
    }
    float noise(vec2 uv)
    {
     	vec2 i = floor(uv);
        vec2 f = fract(uv);

        float a = random(i);
        float b = random(i + vec2(1.0,0.0));
    	float c = random(i + vec2(0.0, 1.0));
        float d = random(i + vec2(1.0));

        vec2 u = smoothstep(0.0, 1.0, f);

        return mix(a,b, u.x) + (c - a) * u.y * (1. - u.x) + (d - b) * u.x * u.y;

    }


    vec2 scandistort(vec2 uv) {
    	float scan1 = clamp(cos(uv.y * 2.0 + iTime), 0.0, 1.0);
    	float scan2 = clamp(cos(uv.y * 2.0 + iTime + 4.0) * 10.0, 0.0, 1.0) ;
    	float amount = scan1 * scan2 * uv.x;

    	//uv.x -= 0.05 * mix(flixel_texture2D(noiseTex, vec2(uv.x, amount)).r * amount, amount, 0.9);

    	return uv;

    }
    void main()
    {
    #pragma body

    	vec2 uv = openfl_TextureCoordv;
      vec2 curUV = screenDistort(uv);
    	uv = scandistort(curUV);
    	vec4 video = getVideo(uv);
      float vigAmt = 1.0;
      float x =  0.0;


      if (rgb) {
            video.r = getVideo(vec2(x+uv.x+0.001,uv.y+0.001)).x+0.05;
            video.g = getVideo(vec2(x+uv.x+0.000,uv.y-0.002)).y+0.05;
            video.b = getVideo(vec2(x+uv.x-0.002,uv.y+0.000)).z+0.05;
            video.r += 0.08*getVideo(0.75*vec2(x+0.025, -0.027)+vec2(uv.x+0.001,uv.y+0.001)).x;
            video.g += 0.05*getVideo(0.75*vec2(x+-0.022, -0.02)+vec2(uv.x+0.000,uv.y-0.002)).y;
            video.b += 0.08*getVideo(0.75*vec2(x+-0.02, -0.018)+vec2(uv.x-0.002,uv.y+0.000)).z;
      }

      video = clamp(video*0.6+0.4*video*video*1.0,0.0,1.0);
      if(vignetteMoving)
    	  vigAmt = 3.0+0.3*sin(iTime + 5.0*cos(iTime*5.0));

    	float vignette = (1.0-vigAmt*(uv.y-0.5)*(uv.y-0.5))*(1.0-vigAmt*(uv.x-0.5)*(uv.x-0.5));

      if(vignetteOn)
    	 video *= vignette;


      if(noise) {
    	 gl_FragColor = mix(video,vec4(noise(uv * 75.0)),0.05);
      }else{
          gl_FragColor = video;
      }

      if(curUV.x<0.0 || curUV.x>1.0 || curUV.y<0.0 || curUV.y>1.0){
        gl_FragColor = vec4(0.0,0.0,0.0,0.0);
      }

    }
  ')
	public function new()
	{
		super();
	}
}

class DistortionEffect extends Effect
{
	public var shader:DistortionShader;

	public function new(glitchFactor:Float, otherglitch:Float, ?pushUpdate:Bool = true)
	{
		shader = new DistortionShader();
		shader.iTime.value = [0];
		shader.glitchModifier.value = [glitchFactor];
		shader.moveScreenFullX.value = [true];
		shader.moveScreenX.value = [true];
		shader.moveScreenFullY.value = [true];
		shader.fullglitch.value = [otherglitch];
		shader.working.value = [true];
		shader.timeMulti.value = [1.0];
		shader.effectMulti.value = [1.0];

		shader.iResolution.value = [Lib.current.stage.stageWidth, Lib.current.stage.stageHeight];
		if (pushUpdate)
			PlayState.instance.shaderUpdates.push(update);
	}

	public function update(elapsed:Float)
	{
		shader.iTime.value[0] += elapsed;
		shader.iResolution.value = [Lib.current.stage.stageWidth, Lib.current.stage.stageHeight];
	}

	public function setGlitchModifier(modifier:Float)
	{
		shader.glitchModifier.value[0] = modifier;
	}
}

class DistortionShader extends FlxShader
{
	@:glFragmentSource('
        #pragma header

        uniform float iTime;
        uniform float glitchModifier;
        uniform vec3 iResolution;
		uniform bool moveScreenFullX;
		uniform bool moveScreenX;
		uniform bool moveScreenFullY;
		uniform float fullglitch;
		uniform bool working;
		uniform float timeMulti;
		uniform float effectMulti;

		vec3 mod289(vec3 x) {
			return x - floor(x * (1.0 / 289.0)) * 289.0;
		}

		vec2 mod289(vec2 x) {
			return x - floor(x * (1.0 / 289.0)) * 289.0;
		}

		vec3 permute(vec3 x) {
			return mod289(((x*34.0)+1.0)*x);
		}

		float snoise(vec2 v)
		{
			 const vec4 C = vec4(0.211324865405187,  // (3.0-sqrt(3.0))/6.0
                      0.366025403784439,  // 0.5*(sqrt(3.0)-1.0)
                     -0.577350269189626,  // -1.0 + 2.0 * C.x
                      0.024390243902439); // 1.0 / 41.0
	
			// First corner
			vec2 i  = floor(v + dot(v, C.yy) );
			vec2 x0 = v -   i + dot(i, C.xx);

			// Other corners
			vec2 i1;
			//i1.x = step( x0.y, x0.x ); // x0.x > x0.y ? 1.0 : 0.0
			//i1.y = 1.0 - i1.x;
			i1 = (x0.x > x0.y) ? vec2(1.0, 0.0) : vec2(0.0, 1.0);
			// x0 = x0 - 0.0 + 0.0 * C.xx ;
			// x1 = x0 - i1 + 1.0 * C.xx ;
			// x2 = x0 - 1.0 + 2.0 * C.xx ;
			vec4 x12 = x0.xyxy + C.xxzz;
			x12.xy -= i1;

			// Permutations
			i = mod289(i); // Avoid truncation effects in permutation
			vec3 p = permute( permute( i.y + vec3(0.0, i1.y, 1.0 ))
					+ i.x + vec3(0.0, i1.x, 1.0 ));

			vec3 m = max(0.5 - vec3(dot(x0,x0), dot(x12.xy,x12.xy), dot(x12.zw,x12.zw)), 0.0);
			m = m*m ;
			m = m*m ;

			// Gradients: 41 points uniformly over a line, mapped onto a diamond.
			// The ring size 17*17 = 289 is close to a multiple of 41 (41*7 = 287)

			vec3 x = 2.0 * fract(p * C.www) - 1.0;
			vec3 h = abs(x) - 0.5;
			vec3 ox = floor(x + 0.5);
			vec3 a0 = x - ox;

			// Normalise gradients implicitly by scaling m
			// Approximation of: m *= inversesqrt( a0*a0 + h*h );
			m *= 1.79284291400159 - 0.85373472095314 * ( a0*a0 + h*h );

			// Compute final noise value at P
			vec3 g;
			g.x  = a0.x  * x0.x  + h.x  * x0.y;
			g.yz = a0.yz * x12.xz + h.yz * x12.yw;
			return (fullglitch * 130.0) * dot(m, g);
		}
    
        float onOff(float a, float b, float c)
        {
          	return step(c, sin(iTime + a*cos(iTime*b)));
        }
    
        float ramp(float y, float start, float end)
        {
          	float inside = step(start,y) - step(end,y);
          	float fact = (y-start)/(end-start)*inside;
          	return (1.0-fact) * inside;
        }
    
        vec4 getVideo(vec2 uv)
		{
			vec2 look = uv;

			if (moveScreenFullX) {
				float time = (iTime * 2.0);
				
				// Create large, incidental noise waves
				float noise2 = max(0.0, snoise(vec2(time, uv.y * 0.3)) - 0.3) * (1.0 / 0.7);
				
				// Offset by smaller, constant noise waves
				noise2 = noise2 + (snoise(vec2(time*10.0, uv.y * 2.4)) - 0.5) * 0.15;
				
				// Apply the noise as x displacement for every line
				float xpos = uv.x - noise2 * noise2 * 0.25;

				look = vec2(xpos, uv.y);
			}

            float window = 1.0/(1.0+20.0*(look.y-mod(iTime/4.0,1.0))*(look.y-mod(iTime/4.0,1.0)));
			if (moveScreenX) {
				look.x = look.x + (sin(look.y*10.0 + iTime)/50.0*onOff((4.0 * timeMulti),(4.0 * timeMulti),(0.3 * timeMulti))*(1.0+cos(iTime*80.0))*window)*(glitchModifier*2.0);
			}
          

            float vShift = 0.4*onOff((2.0 * timeMulti),(3.0 * timeMulti),(0.9 * timeMulti))*(sin((iTime * effectMulti))*sin((iTime * effectMulti)*20.0) + (0.5 + 0.1*sin((iTime * effectMulti)*200.0)*cos((iTime * effectMulti))));
            look.y = mod(look.y + vShift*glitchModifier, 1.0);
			
            vec4 video = flixel_texture2D(bitmap,look);

			return video;
		}
		
        float random(vec2 uv)
        {
           return fract(sin(dot(uv, vec2(15.5151, 42.2561))) * 12341.14122 * sin(iTime * 0.03));
        }

        float noise(vec2 uv)
        {
           	vec2 i = floor(uv);
            vec2 f = fract(uv);
    
            float a = random(i);
            float b = random(i + vec2(1.0,0.0));
          	float c = random(i + vec2(0.0, 1.0));
            float d = random(i + vec2(1.0));
    
            vec2 u = smoothstep(0.0, 1.0, f);
    
            return mix(a,b, u.x) + (c - a) * u.y * (1. - u.x) + (d - b) * u.x * u.y;
        }
    
    
        vec2 scandistort(vec2 uv) {
			float scan1 = clamp(cos(uv.y * 2.0 + iTime), 0.0, 1.0);
			float scan2 = clamp(cos(uv.y * 2.0 + iTime + 4.0) * 10.0, 0.0, 1.0) ;
			float amount = scan1 * scan2 * uv.x;
		
			return uv;
        }

        void main()
        {
			#pragma body

			if (working) {
				vec2 uv = openfl_TextureCoordv;

				uv = scandistort(uv);
				vec4 video = getVideo(uv);
				
				gl_FragColor = video;
			} else {
				vec2 uv = openfl_TextureCoordv;

				gl_FragColor = flixel_texture2D(bitmap,uv); // this has to be here lmao 
			}
        }
  	')
	public function new()
	{
		super();
	}
}

class BlurEffect extends Effect
{
	public var shader:BlurShader;

	public function new(?size:Float = 18.0, ?qualitly:Float = 8.0, ?dim:Float = 1.8, ?directions:Float = 16.0)
	{
		shader = new BlurShader();
		shader.Size.value = [size];
		shader.Quality.value = [qualitly];
		shader.dim.value = [dim];
		shader.Directions.value = [directions];
	}

	public function setSize(modifier:Float)
	{
		shader.Size.value = [modifier];
	}

	public function setDim(mod:Float)
	{
		shader.dim.value = [mod];
	}
}

class BlurShader extends FlxShader
{
	@:glFragmentSource('
	#pragma header

    // GAUSSIAN BLUR SETTINGS
  	uniform float dim;
    uniform float Directions;
    uniform float Quality; 
    uniform float Size; 

	void main(void)
	{
		#pragma body
		vec2 uv = openfl_TextureCoordv.xy ;

		float Pi = 6.28318530718; // Pi*2

		vec4 Color = texture2D( bitmap, uv);
		
		for(float d=0.0; d<Pi; d+=Pi/Directions){
			for(float i=1.0/Quality; i<=1.0; i+=1.0/Quality){

				float ex = (cos(d)*Size*i)/openfl_TextureSize.x;
				float why = (sin(d)*Size*i)/openfl_TextureSize.y;
				Color += flixel_texture2D( bitmap, uv+vec2(ex,why));	
			}
		}
		
		Color /= (dim * Quality) * Directions - 15.0;
		vec4 bloom =  (flixel_texture2D( bitmap, uv)/ dim)+Color;

		gl_FragColor = bloom;

	}
	')
	public function new()
	{
		super();
	}
}

class BloomEffect extends Effect
{
	public var shader:BloomShader;

	public function new(blurSize:Float, intensity:Float)
	{
		shader = new BloomShader();
		shader.blurSize.value = [blurSize];
		shader.intensity.value = [intensity];
	}
}

class BloomShader extends FlxShader
{
	@:glFragmentSource('
	
	#pragma header
	
	uniform float intensity;
	uniform float blurSize;
void main()
{
	#pragma body
   vec4 sum = vec4(0);
   vec2 texcoord = openfl_TextureCoordv;
   int j;
   int i;

   //thank you! http://www.gamerendering.com/2008/10/11/gaussian-blur-filter-shader/ for the 
   //blur tutorial
   // blur in y (vertical)
   // take nine samples, with the distance blurSize between them
   sum += flixel_texture2D(bitmap, vec2(texcoord.x - 4.0*blurSize, texcoord.y)) * 0.05;
   sum += flixel_texture2D(bitmap, vec2(texcoord.x - 3.0*blurSize, texcoord.y)) * 0.09;
   sum += flixel_texture2D(bitmap, vec2(texcoord.x - 2.0*blurSize, texcoord.y)) * 0.12;
   sum += flixel_texture2D(bitmap, vec2(texcoord.x - blurSize, texcoord.y)) * 0.15;
   sum += flixel_texture2D(bitmap, vec2(texcoord.x, texcoord.y)) * 0.16;
   sum += flixel_texture2D(bitmap, vec2(texcoord.x + blurSize, texcoord.y)) * 0.15;
   sum += flixel_texture2D(bitmap, vec2(texcoord.x + 2.0*blurSize, texcoord.y)) * 0.12;
   sum += flixel_texture2D(bitmap, vec2(texcoord.x + 3.0*blurSize, texcoord.y)) * 0.09;
   sum += flixel_texture2D(bitmap, vec2(texcoord.x + 4.0*blurSize, texcoord.y)) * 0.05;
	
	// blur in y (vertical)
   // take nine samples, with the distance blurSize between them
   sum += flixel_texture2D(bitmap, vec2(texcoord.x, texcoord.y - 4.0*blurSize)) * 0.05;
   sum += flixel_texture2D(bitmap, vec2(texcoord.x, texcoord.y - 3.0*blurSize)) * 0.09;
   sum += flixel_texture2D(bitmap, vec2(texcoord.x, texcoord.y - 2.0*blurSize)) * 0.12;
   sum += flixel_texture2D(bitmap, vec2(texcoord.x, texcoord.y - blurSize)) * 0.15;
   sum += flixel_texture2D(bitmap, vec2(texcoord.x, texcoord.y)) * 0.16;
   sum += flixel_texture2D(bitmap, vec2(texcoord.x, texcoord.y + blurSize)) * 0.15;
   sum += flixel_texture2D(bitmap, vec2(texcoord.x, texcoord.y + 2.0*blurSize)) * 0.12;
   sum += flixel_texture2D(bitmap, vec2(texcoord.x, texcoord.y + 3.0*blurSize)) * 0.09;
   sum += flixel_texture2D(bitmap, vec2(texcoord.x, texcoord.y + 4.0*blurSize)) * 0.05;

   //increase blur with intensity!
  gl_FragColor = sum*intensity + flixel_texture2D(bitmap, texcoord); 
  // if(sin(iTime) > 0.0)
   //    fragColor = sum * sin(iTime)+ texture(iChannel0, texcoord);
  // else
	//   fragColor = sum * -sin(iTime)+ texture(iChannel0, texcoord);
}
	
	
	')
	public function new()
	{
		super();
	}
}

class GlitchEffect extends Effect
{
    public var shader:GlitchShader = new GlitchShader();

    public var waveSpeed(default, set):Float = 0;
	public var waveFrequency(default, set):Float = 0;
	public var waveAmplitude(default, set):Float = 0;

	public function new(waveSpeed:Float,waveFrequency:Float,waveAmplitude:Float):Void
	{
		shader.uTime.value = [0];
		this.waveSpeed = waveSpeed;
		this.waveFrequency = waveFrequency;
		this.waveAmplitude = waveAmplitude;
		PlayState.instance.shaderUpdates.push(update);
	}

    public function update(elapsed:Float):Void
    {
        shader.uTime.value[0] += elapsed;
    }

    function set_waveSpeed(v:Float):Float
    {
        waveSpeed = v;
        shader.uSpeed.value = [waveSpeed];
        return v;
    }
    
    function set_waveFrequency(v:Float):Float
    {
        waveFrequency = v;
        shader.uFrequency.value = [waveFrequency];
        return v;
    }
    
    function set_waveAmplitude(v:Float):Float
    {
        waveAmplitude = v;
        shader.uWaveAmplitude.value = [waveAmplitude];
        return v;
    }
}

class DistortBGEffect extends Effect
{
    public var shader:DistortBGShader = new DistortBGShader();

    public var waveSpeed(default, set):Float = 0;
	public var waveFrequency(default, set):Float = 0;
	public var waveAmplitude(default, set):Float = 0;

	public function new(waveSpeed:Float,waveFrequency:Float,waveAmplitude:Float):Void
	{
		this.waveSpeed = waveSpeed;
		this.waveFrequency = waveFrequency;
		this.waveAmplitude = waveAmplitude;
		shader.uTime.value = [0];
		PlayState.instance.shaderUpdates.push(update);
	}

    public function update(elapsed:Float):Void
    {
        shader.uTime.value[0] += elapsed;
    }

    function set_waveSpeed(v:Float):Float
    {
        waveSpeed = v;
        shader.uSpeed.value = [waveSpeed];
        return v;
    }
    
    function set_waveFrequency(v:Float):Float
    {
        waveFrequency = v;
        shader.uFrequency.value = [waveFrequency];
        return v;
    }
    
    function set_waveAmplitude(v:Float):Float
    {
        waveAmplitude = v;
        shader.uWaveAmplitude.value = [waveAmplitude];
        return v;
    }
}

class InvertColorsEffect extends Effect
{
	public var shader:InvertShader = new InvertShader();

	public function new(lockAlpha)
	{
		//	shader.lockAlpha.value = [lockAlpha];
	}
}

class GlitchShader extends FlxShader
{
    @:glFragmentSource('
    #pragma header
    //uniform float tx, ty; // x,y waves phase

    //modified version of the wave shader to create weird garbled corruption like messes
    uniform float uTime;
    
    /**
     * How fast the waves move over time
     */
    uniform float uSpeed;
    
    /**
     * Number of waves over time
     */
    uniform float uFrequency;
    
    /**
     * How much the pixels are going to stretch over the waves
     */
    uniform float uWaveAmplitude;

    vec2 sineWave(vec2 pt)
    {
        float x = 0.0;
        float y = 0.0;
        
        float offsetX = sin(pt.y * uFrequency + uTime * uSpeed) * (uWaveAmplitude / pt.x * pt.y);
        float offsetY = sin(pt.x * uFrequency - uTime * uSpeed) * (uWaveAmplitude / pt.y * pt.x);
        pt.x += offsetX; // * (pt.y - 1.0); // <- Uncomment to stop bottom part of the screen from moving
        pt.y += offsetY;

        return vec2(pt.x + x, pt.y + y);
    }

    void main()
    {
    	#pragma body
        vec2 uv = sineWave(openfl_TextureCoordv);
        gl_FragColor = texture2D(bitmap, uv);
    }')

    public function new()
    {
       super();
    }
}

class InvertShader extends FlxShader
{
    @:glFragmentSource('
    #pragma header
    
    vec4 sineWave(vec4 pt)
    {
	
	return vec4(1.0 - pt.x, 1.0 - pt.y, 1.0 - pt.z, pt.w);
    }

    void main()
    {
    	#pragma body
        vec2 uv = openfl_TextureCoordv;
        gl_FragColor = sineWave(texture2D(bitmap, uv));
		gl_FragColor.a = 1.0 - gl_FragColor.a;
    }')

    public function new()
    {
       super();
    }
}

class DistortBGShader extends FlxShader
{
    @:glFragmentSource('
    #pragma header
    //uniform float tx, ty; // x,y waves phase

    //gives the character a glitchy, distorted outline
    uniform float uTime;
    
    /**
     * How fast the waves move over time
     */
    uniform float uSpeed;
    
    /**
     * Number of waves over time
     */
    uniform float uFrequency;
    
    /**
     * How much the pixels are going to stretch over the waves
     */
    uniform float uWaveAmplitude;

    vec2 sineWave(vec2 pt)
    {
        float x = 0.0;
        float y = 0.0;
        
        float offsetX = sin(pt.x * uFrequency + uTime * uSpeed) * (uWaveAmplitude / pt.x * pt.y);
        float offsetY = sin(pt.y * uFrequency - uTime * uSpeed) * (uWaveAmplitude);
        pt.x += offsetX; // * (pt.y - 1.0); // <- Uncomment to stop bottom part of the screen from moving
        pt.y += offsetY;

        return vec2(pt.x + x, pt.y + y);
    }

    vec4 makeBlack(vec4 pt)
    {
        return vec4(0, 0, 0, pt.w);
    }

    void main()
    {
    	#pragma body
        vec2 uv = sineWave(openfl_TextureCoordv);
        gl_FragColor = makeBlack(texture2D(bitmap, uv)) + texture2D(bitmap,openfl_TextureCoordv);
    }')

    public function new()
    {
       super();
    }
}

class Effect
{
	public function setValue(shader:FlxShader, variable:String, value:Float)
	{
		Reflect.setProperty(Reflect.getProperty(shader, 'variable'), 'value', [value]);
	}
}