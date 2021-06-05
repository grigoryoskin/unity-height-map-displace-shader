## Shader for rendering a surface from a heghtmap.

Inspired by displace shader in blender.

![ezgif-6-e7fdb010b078](https://user-images.githubusercontent.com/44236259/120804672-e517e900-c57f-11eb-98a7-7be6e01f52f3.gif)

To use it, assign it to a material and add to a default unity cube. It uses a ray marching/parallax algorythm. For it to work efficiently, we need to calculate the positions of back faces of the mesh to define ray bounds. Some solutions exist that render back faces in a separate pass, but I wanted to keep it simple and used a ray - box intersection algorythm, so it works only on a cube. 
All positions and directions are in the cube's objject space, so all transforms of the cube proportianally transform the surface too.
