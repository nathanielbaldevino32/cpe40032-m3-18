
PlayState = Class{__includes = BaseState}

--[[
    We initialize what's in our PlayState via a state table that we pass between
    states as we go from playing to serving.
]]
function PlayState:enter(params)
    self.paddle = params.paddle
    self.bricks = params.bricks
    self.health = params.health
    self.score = params.score
    self.highScores = params.highScores
    self.scoreCounter = params.scoreCounter
    --MODIFY SELF.BALL TO ARRAY FOR WE HAVE NOW MULTIPLE BALL SPAWNING
    self.balls = {params.ball} 
    self.level = params.level

    self.powerup = Powerup()
    --CALLS POWERUP CLASS

    self.keyTaken = false ----locked bricked 
    --VARIABLE TO BE USED IN CHECKING WETHER WE HAVE THE KEY OR NOT
    

    self.recoverPoints = 2000

    -- give ball random starting velocity
    --INITIAL BALL VELOCITY
    self.balls[1].dx = math.random(-200, 200)
    self.balls[1].dy = math.random(-50, -60)

    gSounds['play']:play()
    gSounds['play']:setLooping(true)
end

function PlayState:update(dt)
    if self.paused then
        if love.keyboard.wasPressed('space') then
            self.paused = false
            gSounds['pause']:play()
            love.audio.resume()
        else
            return
        end
    elseif love.keyboard.wasPressed('space') then
        self.paused = true
        gSounds['pause']:play()
        love.audio.pause()
        return
    end

    -- handle powerup spawn
    self.powerup.timer = self.powerup.timer + dt
    if not self.powerup.inPlay and self.powerup.timer > self.powerup.spawnTime then
        if math.random(1, 100) < 50 then
            if not self.keyTaken and self:blockedBrickSpawned() then
                self.powerup.type = 2  --key
                self.powerup.inPlay = true
                --SPAWNS THE KEY IF WE DON'T STILL HAS IT
            elseif #self.balls == 1 then
                print(#self.balls)  -- multiball
                self.powerup.type = 1
                self.powerup.inPlay = true
                --SPAWNS THE MULTIBALL POWERUP WHEN WE HAVE THE KEY
            end
        end
        self.powerup.timer = 0
        --RESETS POWERUP TIMER TO 0
    end

    if self.powerup.inPlay then
        self.powerup:update(dt)
    end

    -- handle powerup collision
    --POWERUP COLLISON 
    if self.powerup:collides(self.paddle) then
        if self.powerup.type == 1 then
            local b = Ball(math.random(7))
            b.x = self.balls[1].x
            b.y = self.balls[1].y
            b.dx = math.random(-200, 200)
            b.dy = math.random(-50, -60)
            table.insert(self.balls, b)
            local b2 = Ball(math.random(7))
            b2.x = self.balls[1].x
            b2.y = self.balls[1].y
            b2.dx = math.random(-200, 200)
            b2.dy = math.random(-50, -60)
            table.insert(self.balls, b2)
            --SHRINKS THE PADDLE WHEN THE PADDLE COLLIDES WITH THE MULTIBALL POWERUP
        elseif self.powerup.type == 2 then
            self.keyTaken = true
            --
        end
    end

    -- update positions based on velocity
    self.paddle:update(dt)

    --MODIFY THE CODES RELATED TO BALL , CHANGE THIS TO FOR LOOP , FOR WE HAVE NOW AN ARRAY/TABLE OF BALLS
    for i, ball in pairs(self.balls) do
        ball:update(dt)

        if ball:collides(self.paddle) then
            -- raise ball above paddle in case it goes below it, then reverse dy
            ball.y = self.paddle.y - 8
            ball.dy = -ball.dy
            --
            -- tweak angle of bounce based on where it hits the paddle
            --

            -- if we hit the paddle on its left side while moving left...
            if ball.x < self.paddle.x + (self.paddle.width / 2) and self.paddle.dx < 0 then
                ball.dx = -50 + -(8 * (self.paddle.x + self.paddle.width / 2 - ball.x))
            
            -- else if we hit the paddle on its right side while moving right...
            elseif ball.x > self.paddle.x + (self.paddle.width / 2) and self.paddle.dx > 0 then
                ball.dx = 50 + (8 * math.abs(self.paddle.x + self.paddle.width / 2 - ball.x))
            end

            gSounds['paddle-hit']:play()
        end

        -- detect collision across all bricks with the balls
        for k, brick in pairs(self.bricks) do

            -- only check collision if we're in play
            if brick.inPlay and ball:collides(brick) then

                -- handle locked brick
                --lockednbricked
                --UNLOCKS THE BRICK IF WE HAVE THE KEY
                if self.keyTaken and brick.locked then
                    brick:hit()
                    brick.locked = false
                    
                end

                -- add to score
                self.score = self.score + (brick.tier * 200 + brick.color * 25)

                -- trigger the brick's hit function, which removes it from play
                brick:hit()

                -- if we have enough points, recover a point of health
                if self.score > self.recoverPoints then
                   
                    -- multiply recover points by 2
                   -- self.recoverPoints = math.min(100000, self.recoverPoints * 2)

                    -- grow paddle
                    --PADDLE GROWS EVERY 2000 POINTS GAINED
                    self.paddle:grow()

                    -- play recover sound effect
                    gSounds['recover']:play()

                    self.recoverPoints = self.score + 2000
                end
                

                -- go to our victory screen if there are no more bricks left
                if self:checkVictory() then
                    love.audio.stop()
                    gSounds['victory']:play()
                    --gives the player 1 heart once he/she finished a level
                    self.health = math.min(3, self.health + 1) 

                    gStateMachine:change('victory', {
                        level = self.level,
                        paddle = self.paddle,
                        health = self.health,
                        score = self.score,
                        highScores = self.highScores,
                        ball = Ball(math.random(7)),
                        recoverPoints = self.recoverPoints
                        
                    })
                end


                --
                -- collision code for bricks
                --
                -- we check to see if the opposite side of our velocity is outside of the brick;
                -- if it is, we trigger a collision on that side. else we're within the X + width of
                -- the brick and should check to see if the top or bottom edge is outside of the brick,
                -- colliding on the top or bottom accordingly 
                --

                -- left edge; only check if we're moving right, and offset the check by a couple of pixels
                -- so that flush corner hits register as Y flips, not X flips
                if ball.x + 2 < brick.x and ball.dx > 0 then
                    
                    -- flip x velocity and reset position outside of brick
                    ball.dx = -ball.dx
                    ball.x = brick.x - 8
                
                -- right edge; only check if we're moving left, , and offset the check by a couple of pixels
                -- so that flush corner hits register as Y flips, not X flips
                elseif ball.x + 6 > brick.x + brick.width and ball.dx < 0 then
                    
                    -- flip x velocity and reset position outside of brick
                    ball.dx = -ball.dx
                    ball.x = brick.x + 32
                
                -- top edge if no X collisions, always check
                elseif ball.y < brick.y then
                    
                    -- flip y velocity and reset position outside of brick
                    ball.dy = -ball.dy
                    ball.y = brick.y - 8
                
                -- bottom edge if no X collisions or top collision, last possibility
                else
                    
                    -- flip y velocity and reset position outside of brick
                    ball.dy = -ball.dy
                    ball.y = brick.y + 16
                end

                -- slightly scale the y velocity to speed up the game, capping at +- 150
                if math.abs(ball.dy) < 150 then
                    ball.dy = ball.dy * 1.02
                end

                -- only allow colliding with one brick, for corners
                break
            end
        end

        -- if ball goes below bounds, revert to serve state and decrease health
        if ball.y >= VIRTUAL_HEIGHT then
            if #self.balls == 1 then
                self.health = self.health - 1
                gSounds['hurt']:play()
                -- paddle shrinks when a life was lost
                self.paddle:shrink()

                if self.health == 0 then
                    love.audio.pause()
                    gStateMachine:change('game-over', {
                        score = self.score,
                        highScores = self.highScores
                    })
                else
                    gStateMachine:change('serve', {
                        paddle = self.paddle,
                        bricks = self.bricks,
                        health = self.health,
                        score = self.score,
                        highScores = self.highScores,
                        level = self.level,
                        recoverPoints = self.recoverPoints,
                    })
                end
            else
              --REMOVE TABLE OF BALLS WHEN THE GAME IS OVER
                table.remove(self.balls, i)
            end
        end
    end

    -- for rendering particle systems
    for k, brick in pairs(self.bricks) do
        brick:update(dt)
    end

    if love.keyboard.wasPressed('escape') then
        love.event.quit()
    end
end

function PlayState:render()
  --lockedbrick update 5
  --PRINTS TO THE SCREEN IF WE OBTAINED THE KEY
    if self.keyTaken then
        love.graphics.print("KEY ACQUIRED", 25, 200)
    end

    -- render bricks
    for k, brick in pairs(self.bricks) do
        brick:render()
    end

    -- render all particle systems
    for k, brick in pairs(self.bricks) do
        brick:renderParticles()
    end

    self.paddle:render()
    self.powerup:render()
--powerup update 5.6
--MODIFY TO FOR LOOP
    for i, ball in pairs(self.balls) do
        ball:render()
    end

    renderScore(self.score)
    renderHealth(self.health)

    -- pause text, if paused
    if self.paused then
        love.graphics.setFont(gFonts['large'])
        love.graphics.printf("PAUSED", 0, VIRTUAL_HEIGHT / 2 - 16, VIRTUAL_WIDTH, 'center')
    end
end

function PlayState:checkVictory()
    for k, brick in pairs(self.bricks) do
        if brick.inPlay then
            return false
        end 
    end

    return true
end

--lockedbricked 6
--LOOP THAT CHECKS IF LOCKEDBRICK SPAWNED
function PlayState:blockedBrickSpawned()
    for k, brick in pairs(self.bricks) do
        if brick.inPlay and brick.locked then
            return true
        end
    end
    return false
end