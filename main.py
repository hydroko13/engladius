import pygame
import threading

class Game:
    def __init__(self):
        self.internal_win_size = (960, 540)
        self.window = pygame.display.set_mode(self.internal_win_size)
        self.clock = pygame.time.Clock()

        self.internal_surface = pygame.Surface(self.internal_win_size, pygame.SRCALPHA)

        self.current_resolution_mode = 0

        self.current_window_size = self.internal_win_size

        self.done = False

        self.dt = 0

    def change_resolution_mode(self, new_resolution_mode):
        self.current_resolution_mode = new_resolution_mode

        if new_resolution_mode == 0:
            self.window = pygame.display.set_mode(self.internal_win_size)
        elif new_resolution_mode == 1:
            monitor_size = pygame.display.get_desktop_sizes()[0]
            self.window = pygame.display.set_mode(monitor_size, pygame.FULLSCREEN)
            self.current_window_size = monitor_size

    def draw(self):
        pass
    
    def update(self):
        pass

    def run(self):
        while not self.done:
            for event in pygame.event.get():
                if event.type == pygame.QUIT:
                    self.done = True
                if event.type == pygame.KEYDOWN:
                    if event.key == pygame.K_F4:
                        self.change_resolution_mode(self.current_resolution_mode + 1 if self.current_resolution_mode < 1 else 0)

            self.window.fill((0, 0, 0))
            self.internal_surface.fill((0, 0, 0))
            self.dt = self.clock.tick(60) / 1000
            self.update()
            self.draw()


            

            scaled_internal_surface = pygame.transform.scale(self.internal_surface, self.current_window_size).convert_alpha()
            self.window.blit(scaled_internal_surface, (0, 0))

            pygame.display.flip()



if __name__ == '__main__':
    pygame.init()
    game = Game()
    game.run()