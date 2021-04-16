-- User: Wilhelm Stuhlpfarrer --
-- Date: 04.04.2021 --


local winHeight, winWidth, scaleFactorHeight, scaleFactorWidth, inverseScaleFactorHeight, inverseScaleFactorWidth
local barL, barR
local scoreL, scoreR, pongCount, winScore
local margin, lineHeight
local baseSpeed, baseBarSpeed
local baseSpeedChange, baseBarSpeedChange, winScoreChange
local debug
local isDebugOn, hasGameStarted, isPaused, isGameOver
local c, a, f -- color, asset and font table


-- LOAD FUNCTION --
function love.load()
  debug = {}

  -- colors
  c = {lightGrey = {0.8, 0.8, 0.8}, blue = {0.1, 0, 1}, red = {1, 0, 0.1},
  green = {0, 0.9, 0.2}, purple = {0.54117, 0, 0.54117}, orange = {1, 0.5, 0}}

  love.window.setFullscreen(true)
  love.window.setMode(0, 0, {display = 1})
  winWidth, winHeight = love.graphics.getDimensions()

  -- scale factor based on 1440p resolution
  scaleFactorHeight = winHeight / 1440
  scaleFactorWidth = winWidth / 2560
  inverseScaleFactorHeight = 1440 / winHeight
  inverseScaleFactorWidth = 2560 / winWidth

  -- load all assets
  a = {
    imgScale = 0.8 * scaleFactorHeight,
    shrink = false, -- bool for image scaling direction
    pongImg = love.graphics.newImage("img/pongO.png"),
    leftWinImg = love.graphics.newImage("img/leftWon2.png"),
    rightWinImg = love.graphics.newImage("img/rightWon2.png"),
    bgStars = {img = love.graphics.newImage("img/spaceBgS.jpg"), y = 0, baseSpeed = -30 * scaleFactorHeight, speed = baseSpeed},
    bonusStars1 = {img = love.graphics.newImage("img/bonus_stars1.png"), y = 0, baseSpeed = -50 * scaleFactorHeight, speed = baseSpeed},
    bonusStars2 = {img = love.graphics.newImage("img/bonus_stars2.png"), y = 0, baseSpeed = -70 * scaleFactorHeight, speed = baseSpeed},
    bgRocks = {img = love.graphics.newImage("img/rocks.png"), y = 0, baseSpeed = -100 * scaleFactorHeight, speed = baseSpeed},
    rocksLeft = {img = love.graphics.newImage("img/rocks_red.png"), scale = 1 * scaleFactorHeight},
    rocksRight = {img = love.graphics.newImage("img/rocks_blue.png"), scale = 1 * scaleFactorHeight},
    pongSoundBar = love.audio.newSource("pong.wav", "static"),
    pongSoundTopBottom = love.audio.newSource("pong.wav", "static")
  }
  a.pongSoundTopBottom:setPitch(0.8)
  a.pongSoundTopBottom:setVolume(0.8)

  -- margin at borders
  margin = 20 * scaleFactorHeight
  -- line height of small font
  lineHeight = winHeight / 25

  -- fonts
  f = {
    font = love.graphics.newFont("font/ff.ttf", 180 * scaleFactorHeight),
    font2 = love.graphics.newFont("font/agencyfb.ttf", 120 * scaleFactorHeight),
    font3 = love.graphics.newFont("font/agencyfb.ttf", 50 * scaleFactorHeight)
  }

  -- base values for speed and score
  baseSpeed = 800 * scaleFactorWidth -- adjusted to work on all resolutions
  baseBarSpeed = 1500 * scaleFactorHeight
  winScore = 5
  baseSpeedChange, baseBarSpeedChange, winScoreChange = baseSpeed, baseBarSpeed, winScore
  init()
end

function init()
  hasGameStarted = false
  isPaused = false
  isGameOver = false

  scoreL, scoreR, pongCount = 0, 0, 0

  barL = createBar()
  barR = createBar()

  barL.x = margin
  barL.y = winHeight / 2 - barL.height / 2
  barR.x = winWidth - margin - barR.width
  barR.y = winHeight / 2 - barR.height / 2

  ball = {}
  ball.size = winWidth / 45
  initBall()

  -- init debug informations
  debug[1] = "Status: Game has not started yet"
  debug[2] = "Current angle: "
  debug[3] = "Current direction: "
  debug[4] = "Norm. Intersection: "
  debug[5] = "Current ball speed: "..ball.speed * inverseScaleFactorWidth
  debug[6] = "Current bar speed: "..barL.speed * inverseScaleFactorWidth
  debug[7] = "Score to win: " ..winScore
  debug[8] = "Current bg + rock speeds: " .. a.bgStars.speed * inverseScaleFactorHeight
  .. " | " .. a.bgRocks.speed * inverseScaleFactorHeight
end

function reset()
  -- apply changed speed values
  baseSpeed = baseSpeedChange
  baseBarSpeed = baseBarSpeedChange
  winScore = winScoreChange
  init()
end

-- UPDATE FUNCTION --
function love.update(dt)
  -- move the background images
  a.bgStars.y = (a.bgStars.y - a.bgStars.speed * dt) % winHeight
  a.bonusStars1.y = (a.bonusStars1.y - a.bonusStars1.speed * dt) % winHeight
  a.bonusStars2.y = (a.bonusStars2.y - a.bonusStars2.speed * dt) % winHeight
  a.bgRocks.y = (a.bgRocks.y - a.bgRocks.speed * dt) % winHeight

  -- scale image of start and end screens
  if (not hasGameStarted or isGameOver) and a.imgScale >= 0.8 * scaleFactorHeight and not a.shrink then
    a.shrink = true
  elseif (not hasGameStarted or isGameOver) and a.imgScale <= 0.7 * scaleFactorHeight and a.shrink then
    a.shrink = false
  elseif (not hasGameStarted or isGameOver) and a.shrink then
    a.imgScale = a.imgScale - 0.2 * dt
  elseif (not hasGameStarted or isGameOver) and not a.shrink then
    a.imgScale = a.imgScale + 0.2 * dt
  elseif isPaused then
  else
    -- move bars
    if love.keyboard.isDown("w") and barL.y > margin then
      barL.y = barL.y - dt * barL.speed
    elseif love.keyboard.isDown("s") and barL.y < winHeight - barL.height - margin then
      barL.y = barL.y + dt * barL.speed
    end
    if love.keyboard.isDown("up") and barR.y > margin then
      barR.y = barR.y - dt * barR.speed
    elseif love.keyboard.isDown("down") and barR.y < winHeight - barR.height - margin then
      barR.y = barR.y + dt * barR.speed
    end

    -- assure that bar did not go lower then allowed (happens at lower fps)
    if barL.y < margin then
      barL.y = margin
    elseif barL.y > winHeight - barL.height - margin then
      barL.y = winHeight - barL.height - margin
    end
    if barR.y < margin then
      barR.y = margin
    elseif barR.y > winHeight - barR.height - margin then
      barR.y = winHeight - barR.height - margin
    end

    -- check if ball hit left side
    if ball.x <= margin + barL.width then
      if ball.y + ball.size >= barL.y and ball.y <= barL.y + barL.height
      and ball.direction == -1 and not isGameOver then
        -- hit left bar
        --print("hit bar left")
        a.pongSoundBar:play()
        local angle = getBounceAngleAndUpdateValues(barL)
        debug[1] = "State: Hit left bar"
        debug[2] = "Current angle: "..math.deg(angle)
        debug[3] = "Current direction: ".. 1
        ball.direction = 1
        ball.Vx = math.cos(angle) * ball.speed
        ball.Vy = math.sin(angle) * ball.speed * - 1



      elseif ball.direction == -1 then -- check for direction can bug out otherwise
        -- missed left bar
        --print("missed bar left")

        debug[1] = "State: Missed left bar"
        scoreR = scoreR + 1
        if scoreR >= winScore then
          isGameOver = true
          ball.Vx = 0
          ball.Vy = 0
        else
          initBall()
        end
      end
    end

    -- check if ball hit right side
    if ball.x + ball.size >= barR.x then
      if ball.y + ball.size >= barR.y and ball.y <= barR.y + barR.height
      and ball.direction == 1 and not isGameOver then
        -- hit right bar
        --print("hit bar right")
        a.pongSoundBar:play()
        local angle = getBounceAngleAndUpdateValues(barR)
        debug[1] = "State: Hit right bar"
        debug[2] = "Current angle: "..math.deg(angle)
        debug[3] = "Current direction: ".. - 1
        ball.direction = -1

        ball.Vx = math.cos(angle) * ball.speed * - 1
        ball.Vy = math.sin(angle) * ball.speed * - 1


      elseif ball.direction == 1 then -- check for direction can bug out otherwise
        -- missed right bar
        --print("missed right bar")
        debug[1] = "State: Missed right bar"
        scoreL = scoreL + 1
        if scoreL >= winScore then
          isGameOver = true
          ball.Vx = 0
          ball.Vy = 0
        else
          initBall()
        end
      end
    end

    --check if top/bottom is hit, also check angle -> else can bug out, when fps are not consistent
    if (ball.y + ball.size >= winHeight - margin and ball.angle <= 0) --hit floor
    or (ball.y <= margin and ball.angle >= 0) then --hit ceiling
      a.pongSoundTopBottom:play()
      ball.Vy = -ball.Vy
      ball.angle = -ball.angle
      debug[1] = "Status: Hit top or bottom"
      debug[2] = "Current angle: ".. math.deg(ball.angle)
    end

    -- move ball x/y by its vectors and frame time
    ball.x = ball.x + ball.Vx * dt
    ball.y = ball.y + ball.Vy * dt

  end
end

-- DRAW FUNCTION --
function love.draw()
  --love.graphics.print("Hello World!", 400, 300)

  -- draw scrolling space background
  love.graphics.setColor(1, 1, 1, 0.6)
  love.graphics.draw(a.bgStars.img, 0, a.bgStars.y, 0, scaleFactorWidth, scaleFactorHeight)
  love.graphics.draw(a.bgStars.img, 0, a.bgStars.y - winHeight, 0, scaleFactorWidth, scaleFactorHeight)

  love.graphics.setColor(1, 1, 1, 0.8)
  love.graphics.draw(a.bonusStars1.img, 0, a.bonusStars1.y, 0, scaleFactorWidth, scaleFactorHeight)
  love.graphics.draw(a.bonusStars1.img, 0, a.bonusStars1.y - winHeight, 0, scaleFactorWidth, scaleFactorHeight)

  love.graphics.setColor(1, 1, 1, 0.9)
  love.graphics.draw(a.bonusStars2.img, 0, a.bonusStars2.y, 0, scaleFactorWidth, scaleFactorHeight)
  love.graphics.draw(a.bonusStars2.img, 0, a.bonusStars2.y - winHeight, 0, scaleFactorWidth, scaleFactorHeight)


  -- draw scrolling rocks, left rocks are right one flipped
  love.graphics.setColor(0.7, 0.7, 0.7, 1)
  love.graphics.draw(a.bgRocks.img, winWidth - a.bgRocks.img:getWidth() * scaleFactorHeight, a.bgRocks.y, 0, scaleFactorWidth, scaleFactorHeight)
  love.graphics.draw(a.bgRocks.img, winWidth - a.bgRocks.img:getWidth() * scaleFactorHeight, a.bgRocks.y - winHeight, 0, scaleFactorWidth, scaleFactorHeight)
  love.graphics.draw(a.bgRocks.img, a.bgRocks.img:getWidth() * scaleFactorHeight, a.bgRocks.y, 0, - scaleFactorWidth, scaleFactorHeight)
  love.graphics.draw(a.bgRocks.img, a.bgRocks.img:getWidth() * scaleFactorHeight, a.bgRocks.y - winHeight, 0, - scaleFactorWidth, scaleFactorHeight)

  -- show start screen
  if not hasGameStarted and not isPaused then
    love.graphics.setColor(1, 1, 1)
    love.graphics.draw(a.pongImg, winWidth / 2 - a.pongImg.getWidth(a.pongImg) * 0.5 * a.imgScale, winHeight / 7, 0, a.imgScale, a.imgScale)
    love.graphics.setFont(f.font3)
    love.graphics.setColor(c.lightGrey)
    love.graphics.printf("Press ESCAPE for options!", 0, winHeight - lineHeight, winWidth, 'center')

    -- show pause screen with options
  elseif isPaused then
    love.graphics.setFont(f.font2)
    love.graphics.setColor(c.orange)
    love.graphics.printf("GAME PAUSED", 0, winHeight / 3, winWidth, 'center')

    love.graphics.setFont(f.font3)
    love.graphics.setColor(c.lightGrey)
    love.graphics.print("Settings (only take affect after reset)", winWidth / 10, margin)
    love.graphics.print("Change win score with 1/2", winWidth / 10, margin + winHeight / 25)
    love.graphics.print("Current: " .. winScoreChange, winWidth / 3, margin + lineHeight)
    love.graphics.print("Change ball base speed with 3/4", winWidth / 10, margin + lineHeight * 2)
    love.graphics.print("Current: ".. baseSpeedChange * inverseScaleFactorWidth / 10, winWidth / 3, margin + lineHeight * 2)
    love.graphics.print("Change bar base speed with 5/6", winWidth / 10, margin + lineHeight * 3)
    love.graphics.print("Current: " .. baseBarSpeedChange * inverseScaleFactorWidth / 10, winWidth / 3, margin + lineHeight * 3)
    love.graphics.print("Reset the game with R", winWidth / 10, margin + lineHeight * 5)
    love.graphics.print("Show debug with F1", winWidth / 10, margin + lineHeight * 6)
    love.graphics.setColor(c.green)
    love.graphics.printf("Press ESCAPE to continue", 0, winHeight - lineHeight * 2, winWidth, 'center')
    love.graphics.setColor(c.red)
    love.graphics.printf("Press X to exit", 0, winHeight - lineHeight, winWidth, 'center')

    -- show end screen
  elseif isGameOver then
    love.graphics.setColor(1, 1, 1)
    if scoreL >= winScore then
      love.graphics.draw(a.leftWinImg, winWidth / 2 - a.pongImg.getWidth(a.pongImg) * 0.5 * a.imgScale, winHeight / 7, 0, a.imgScale, a.imgScale)
    else
      love.graphics.draw(a.rightWinImg, winWidth / 2 - a.pongImg.getWidth(a.pongImg) * 0.5 * a.imgScale, winHeight / 7, 0, a.imgScale, a.imgScale)
    end
    love.graphics.setFont(f.font3)
    love.graphics.setColor(c.lightGrey)
    love.graphics.printf("Press SPACE to restart or ESCAPE for options", 0, winHeight - lineHeight * 2, winWidth, 'center')
    love.graphics.setColor(c.red)
    love.graphics.printf("Press X to exit", 0, winHeight - lineHeight, winWidth, 'center')

    -- show score, speed and pong count
  else
    love.graphics.setFont(f.font)
    love.graphics.setColor(c.orange)
    love.graphics.printf(scoreL .. "    |    ".. scoreR, 0, winHeight / 10, winWidth, 'center')
    love.graphics.setFont(f.font3)
    love.graphics.setColor(c.lightGrey)
    love.graphics.printf("Pong count: " .. pongCount, 0, winHeight - lineHeight, winWidth, 'center')
    love.graphics.printf("Current speed: " .. ball.speed * inverseScaleFactorWidth / 10, 0, winHeight - lineHeight, winWidth - winWidth / 11, 'right')
  end

  -- draw the bars, ball and rocks
  love.graphics.setColor(0.9, 0.9, 0.9, 1)
  love.graphics.draw(a.rocksLeft.img, 0, barL.y + barL.height / 2 - (a.rocksLeft.img:getHeight() * a.rocksLeft.scale) / 2, 0, a.rocksLeft.scale, a.rocksLeft.scale)
  love.graphics.setColor(c.red)
  love.graphics.rectangle("fill", barL.x, barL.y, barL.width, barL.height)

  love.graphics.setColor(0.9, 0.9, 0.9, 1)
  love.graphics.draw(a.rocksRight.img, winWidth - a.rocksRight.img:getWidth() * a.rocksRight.scale, barR.y + barR.height / 2 - (a.rocksRight.img:getHeight() * a.rocksRight.scale) / 2, 0, a.rocksRight.scale, a.rocksRight.scale)
  love.graphics.setColor(c.blue)
  love.graphics.rectangle("fill", barR.x, barR.y, barR.width, barR.height)
  love.graphics.setColor(c.lightGrey)
  love.graphics.rectangle("fill", ball.x, ball.y, ball.size, ball.size)
  love.graphics.setColor(c.green)
  love.graphics.setNewFont(20 * scaleFactorHeight)

  -- show debug table
  if isDebugOn then
    for i = 1, #debug do
      love.graphics.print(debug[i], margin, winHeight - winHeight / 6 + (25 * scaleFactorHeight) * i)
    end
  end
end

-- KEY LISTENERS --
function love.keypressed(key, scancode, isrepeat)
  if key == "space" and not isGameOver then
    hasGameStarted = true
    debug[1] = "Status: Game is running"
  elseif key == "space" and isGameOver then
    reset()
  end
  if key == "escape" then
    if isPaused then
      debug[1] = "Status: Game is paused"
    else
      debug[1] = "Status: Game is running"
    end
    isPaused = not isPaused
  end
  if key == "f1" then
    isDebugOn = not isDebugOn
  end
  if key == "x" then
    love.event.quit(0)
  end
  if key == "1" and isPaused and winScoreChange >= 1 then
    winScoreChange = winScoreChange - 1
  end
  if key == "2" and isPaused then
    winScoreChange = winScoreChange + 1
  end
  if key == "3" and isPaused and baseSpeedChange > 100 * inverseScaleFactorWidth then
    baseSpeedChange = baseSpeedChange - 50 * scaleFactorWidth
  end
  if key == "4" and isPaused then
    baseSpeedChange = baseSpeedChange + 50 * scaleFactorWidth
  end
  if key == "5" and isPaused and baseBarSpeedChange > 100 * inverseScaleFactorWidth then
    baseBarSpeedChange = baseBarSpeedChange - 50 * scaleFactorWidth
  end
  if key == "6" and isPaused then
    baseBarSpeedChange = baseBarSpeedChange + 50 * scaleFactorWidth
  end
  if key == "r" and isPaused then
    reset()
  end
end

-- init bars
function createBar()
  local bar = {}
  bar.height = winHeight / 6
  bar.width = winWidth / 50
  bar.speed = baseBarSpeed
  return bar
end

-- return random direction
function getRandomSide()
  if love.math.random(1, 2) == 1 then
    return - 1
  else return 1
  end
end

-- init/reset the ball to center, and give it random direction, reset speed
function initBall()
  ball.x = winWidth / 2 - ball.size / 2
  ball.y = winHeight / 2 - ball.size / 2
  ball.speed = baseSpeed
  barL.speed = baseBarSpeed
  barR.speed = baseBarSpeed
  a.bgStars.speed = a.bgStars.baseSpeed
  a.bonusStars1.speed = a.bonusStars1.baseSpeed
  a.bonusStars2.speed = a.bonusStars2.baseSpeed
  a.bgRocks.speed = a.bgRocks.baseSpeed
  pongCount = 0

  local angle = love.math.random(-70, 70)
  local direction = getRandomSide()
  debug[2] = "Current angle: "..angle
  debug[3] = "Current direction: "..direction
  debug[5] = "Current ball speed: "..ball.speed * inverseScaleFactorWidth
  debug[6] = "Current bar speed: "..barL.speed * inverseScaleFactorWidth
  debug[8] = "Current bg + rock speeds: " .. a.bgStars.speed * inverseScaleFactorHeight
  .. " | " .. a.bgRocks.speed * inverseScaleFactorHeight
  ball.angle = math.rad(angle)
  ball.direction = direction

  ball.Vx = math.cos(math.rad(angle)) * ball.speed * direction
  ball.Vy = math.sin(math.rad(angle)) * ball.speed * - 1
end

-- calculate the angle at which the ball bounces from bars
-- flat angle in center, sharp angle further outside
function getBounceAngleAndUpdateValues(bar)

  -- get relative location where ball hit the bar .. between 1 and -1
  local relativeIntersection = (bar.y + (bar.height / 2)) - (ball.y) - (ball.size / 2)
  local normalizedRelativeIntersection = relativeIntersection / (bar.height / 2 + ball.size / 4)
  debug[4] = "Norm. Intersection: " .. normalizedRelativeIntersection

  -- calculate angle, with maxe angle of 70°
  angle = normalizedRelativeIntersection * math.rad(70)

  -- makes sure that ball wont bounce back in same direction
  if ball.angle < 0 and angle > 0 then
    angle = -angle
  elseif ball.angle > 0 and angle < 0 then
    angle = -angle
  end
  ball.angle = angle

  -- every bounce increases game speeds
  ball.speed = ball.speed + 50 * scaleFactorWidth
  barL.speed = barL.speed + 50 * scaleFactorWidth
  barR.speed = barR.speed + 50 * scaleFactorWidth
  a.bgStars.speed = a.bgStars.speed - 8 * scaleFactorHeight
  a.bonusStars1.speed = a.bonusStars1.speed - 10 * scaleFactorHeight
  a.bonusStars2.speed = a.bonusStars2.speed - 12 * scaleFactorHeight
  a.bgRocks.speed = a.bgRocks.speed - 15 * scaleFactorHeight
  debug[5] = "Current ball speed: "..ball.speed * inverseScaleFactorWidth
  debug[6] = "Current bar speed: "..barL.speed * inverseScaleFactorWidth
  debug[8] = "Current bg + rock speeds: " .. a.bgStars.speed * inverseScaleFactorHeight
  .. " | " .. a.bgRocks.speed * inverseScaleFactorHeight

  pongCount = pongCount + 1
  return angle
end
