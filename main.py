from kivymd.app import MDApp
from kivymd.uix.screenmanager import MDScreenManager

# Import our custom modules
from queue_system import QueueSystem
from login_screen import LoginScreen
from register_screen import RegisterScreen
from user_dashboard import UserDashboardScreen
from admin_dashboard import AdminDashboardScreen


class QueueApp(MDApp):
    def build(self):
        # Set app theme
        self.theme_cls.primary_palette = "Blue"
        self.theme_cls.theme_style = "Light"
        
        # Initialize the queue system backend
        self.queue_system = QueueSystem()
        
        # Create screen manager
        sm = MDScreenManager()
        
        # Create all screens
        login_screen = LoginScreen(name='login')
        register_screen = RegisterScreen(name='register')
        user_screen = UserDashboardScreen(name='user_dashboard')
        admin_screen = AdminDashboardScreen(name='admin_dashboard')
        
        # Connect the queue system to each screen
        login_screen.set_queue_system(self.queue_system)
        register_screen.set_queue_system(self.queue_system)
        user_screen.set_queue_system(self.queue_system)
        admin_screen.set_queue_system(self.queue_system)
        
        # Add all screens to the screen manager
        sm.add_widget(login_screen)
        sm.add_widget(register_screen)
        sm.add_widget(user_screen)
        sm.add_widget(admin_screen)
        
        return sm


if __name__ == '__main__':
    QueueApp().run()