## Shader for rendering a surface from a heghtmap.

Inspired by displace shader in blender.

![ezgif-4-95450c645059](https://user-images.githubusercontent.com/44236259/120880035-b000aa80-c602-11eb-87fb-a2afbc7a8d09.gif)

To use it, assign it to a material and add to a default unity cube. It uses a ray marching/parallax algorithm. For it to work efficiently, we need to calculate the positions of back faces of the mesh to define ray bounds. Some solutions exist that render back faces in a separate pass, but I wanted to keep it simple and used a ray - box intersection algorithm, so it works only on a cube, but allows you to see the surface in scene view. 
All positions and directions are in the cube's object space, so all transforms of the cube proportianally transform the surface too.

I used this project as a reference: https://github.com/IRCSS/UnityRaymarching - It's more involved and uses render textures for back faces.

### TODOs: 
 - Add shadows.
 - Fix normals, I think they look a bit off.
 - ???
