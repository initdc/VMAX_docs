-- A sample scripts for VR controllers interaction with scene
-- Use left stick to set viewport camera direction
-- Use Left, Right, Up, Down, X and Y buttons to move viewport camera
-- Use A and B buttons to chage color of the first light in scene
-- Hold right shoulder button and use the right stick to modify position of the first VRaySun in scene

-- setup maxscript VR interface
fn vrInterfacesSetup =
(
	global iLTouch=null -- "LTouch" controller interface
	global iRTouch=null -- "RTouch" controller interface
	global iRemote=null -- "Remote" controller interface
	global iXBox=null -- "XBox" controller interface

	local rend=renderers.current

	-- check if the current renderer is VRayRT
	local ivrayrt=getinterface rend "vrayrtmax_interface" -- get renderer rtmax interface
	if ivrayrt==null then (
		format "Current renderer is not supported.\n"
		format "This script only works with V-Ray RT in active shade mode.\n"
		return false
	)
	-- intialize VR controller interfaces
	iLTouch=ivrayrt.vrControllerLTouch
	iRTouch=ivrayrt.vrControllerRTouch
	iRemote=ivrayrt.vrControllerRemote
	iXBox=ivrayrt.vrControllerXBox
	true
)

-- sample setup for scene interaction using XBox and Oculus Rift's Remote control
fn vrControllersExample =
(
	global firstLight=lights[1] -- first light in scene
	global firstSun=null -- first sun in scene
	-- previous button states
	global buttonLeft=false, buttonRight=false, buttonUp=false, buttonDown=false, buttonX=false, buttonY=false, buttonA=false, buttonB=false
	-- fixed color palete to use for light color
	global colorPalette=#((color 255 255 255), (color 255 255 0), (color 255 0 255), (color 0 255 255))
	-- current color from the palette
	global currentColor=1

	-- find the first VRaySun in scene
	for i in lights do (
		if firstSun==null and classOf i == VRaySun then (
			firstSun=lights[1]
		)
	)
	--if firstLight!=null then firstLightValue=firstLight.color.v
	global vpCam=viewport.getCamera()

	if firstLight==null then (
		format "Warning: no lights in scene\n"
	)

	if vpCam==null then (
		format "Warning: view navigation requires a camera view\n"
	)
	
	if vrInterfacesSetup() then (
		-- set notification callbacks. Callback is called whenever controller state changes.
		-- ananlog inputs trigger callback invokation when changed beyound the specified theshold value
		-- passes the modified interface as parameter in order to use the same callback for XBox and Remote events
		iXBox.setNotifyCallback "controllerChanged iXBox" 0.15
		iRemote.setNotifyCallback "controllerChanged iRemote" 0.15
	)
	return true
)

-- notification callback - called when XBox or Remote state changes
-- the 'controller' parameter is an interface to either XBox or Remote controller
fn controllerChanged controller =
(

	if controller==null then return false

	-- camera move direction
	local moveDir=[0, 0, 0]

	-- move camera using Up, Down, Left, Right, X and Y buttons
	if controller.buttonUp and not buttonUp then (
		moveDir.y=-1
	)
	if controller.buttonDown and not buttonDown then (
		moveDir.y=1
	)
	if controller.buttonLeft and not buttonLeft then (
		moveDir.x=-1
	)
	if controller.buttonRight and not buttonRight then (
		moveDir.x=1
	)
	if controller.buttonX and not buttonX then (
		moveDir.z=-1
	)
	if controller.buttonY and not buttonY then (
		moveDir.z=1
	)
	-- select light color using the A and B buttons
	local setColor=false
	if controller.buttonA and not buttonA then (
		if (currentColor<1) then currentColor=1
		currentColor+=1
		if currentColor>colorPalette.count then currentColor=1
		setColor=true
	)
	if controller.buttonB and not buttonB then (
		currentColor-=1
		if currentColor<1 then currentColor=colorPalette.count
		setColor=true
	)

	-- move camera and its target
	if vpCam!=null and length moveDir > 0 then (
		local leftVec=vpCam.transform[1]
		local upVec=vpCam.transform[2]
		local viewVec=vpCam.transform[3]
		local trans = vpCam.pos
		local step=getScreenScaleFactor (trans + viewVec)
		moveDir=5*step*(viewVec*moveDir.y + leftVec*moveDir.x + upVec*moveDir.z)
		trans += moveDir
		vpCam.pos=trans
		if vpCam.target!=null then (
			-- move camera target
			vpCam.target.pos+=moveDir
		)
	)

	-- set camera direction using the left stick
	local leftStick=controller.thumbSticks[1]
	local stickLength=length leftStick
	if vpCam!=null and stickLength>0.5 do (
		local target=vpCam.target
		if target!=null then (
			-- target camera: move target according the stick position
			local k=vpCam.targetDistance/stickLength
			target.position.x=vpCam.position.x + k*leftStick.x
			target.position.y=vpCam.position.y + k*leftStick.y
		) else (
			-- free camera - rotate according the sick position
			vpCam.rotation.z_rotation=(atan2 -leftStick.x leftStick.y)
		)
	)

	-- change first light color
	if firstLight!=null and setColor then (
		-- use "color" or "filter_color" property of the first light
		if hasProperty firstLight "color" then (
			firstLight.color=colorPalette[currentColor]
		) else if hasProperty firstLight "filter_color" then (
			firstLight.filter_color=colorPalette[currentColor]
		)
	)

	-- change sun position according lright stick position - only if right shoulder button is pressed
	-- sun distance from camera is preserved
	if firstSun!=null and controller.buttonRShoulder then (
		local direction=controller.thumbSticks[2] -- set direction according right stick position
		local targetPos=[0,0,0]
		if firstSun.target!=0 then targetPos=firstSun.target.position

		if vpCam!=null then (
			-- rotate stick direction according camera XY orientation
			local viewVec=vpCam.transform[3]
			direction=[-direction.x*viewVec.y + direction.y*viewVec.x, -direction.x*viewVec.x - direction.y*viewVec.y]
		)

		-- move the sun according stick direction
		radius=length (firstSun.position - targetPos)
		direction*=80
		local x=radius*(sin direction.x)
		local y=radius*(sin direction.y)
		local r2=radius*radius
		local k=r2/(x*x + y*y)
		if k<1 then (
			-- used to preserve sun distance when stick goes outside a circle with 1.0 radius
			x*=k
			y*=k
		)
		local z=sqrt(r2 - x*x - y*y)
		firstSun.position=[x, y, z] + targetPos
	)

	-- store button states
	buttonLeft=controller.buttonLeft
	buttonRight=controller.buttonRight
	buttonUp=controller.buttonUp
	buttonDown=controller.buttonDown
	buttonX=controller.buttonX
	buttonY=controller.buttonY
	buttonA=controller.buttonA
	buttonB=controller.buttonB
	return true
)

vrControllersExample()
