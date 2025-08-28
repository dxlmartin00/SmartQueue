from kivymd.uix.screen import MDScreen
from kivymd.uix.boxlayout import MDBoxLayout
from kivymd.uix.label import MDLabel
from kivymd.uix.button import MDRaisedButton, MDFlatButton
from kivymd.uix.textfield import MDTextField
from kivymd.uix.snackbar import Snackbar
from kivy.metrics import dp


class LoginScreen(MDScreen):
    def __init__(self, **kwargs):
        super().__init__(**kwargs)
        self.queue_system = None
        self.build_ui()
    
    def set_queue_system(self, queue_system):
        self.queue_system = queue_system
    
    def build_ui(self):
        layout = MDBoxLayout(orientation='vertical', spacing=dp(20), padding=dp(30))
        
        # Title
        title = MDLabel(
            text="SmartQueue",
            theme_text_color="Primary",
            size_hint_y=None,
            height=dp(50),
            halign="center"
        )
        
        # Login form
        self.username_field = MDTextField(
            hint_text="Username",
            icon_right="account",
            size_hint_y=None,
            height=dp(50)
        )
        
        self.password_field = MDTextField(
            hint_text="Password",
            icon_right="lock",
            password=True,
            size_hint_y=None,
            height=dp(50)
        )
        
        login_btn = MDRaisedButton(
            text="LOGIN",
            size_hint_y=None,
            height=dp(40),
            on_release=self.login
        )
        
        register_btn = MDFlatButton(
            text="Register New Account",
            size_hint_y=None,
            height=dp(40),
            on_release=self.go_to_register
        )
        
        layout.add_widget(title)
        layout.add_widget(MDBoxLayout(size_hint_y=None, height=dp(50)))  # Spacer
        layout.add_widget(self.username_field)
        layout.add_widget(self.password_field)
        layout.add_widget(login_btn)
        layout.add_widget(register_btn)
        
        self.add_widget(layout)
    
    def login(self, *args):
        try:
            username = self.username_field.text.strip() if self.username_field.text else ""
            password = self.password_field.text.strip() if self.password_field.text else ""
            
            if not username or not password:
                self.show_message("Please enter both username and password")
                return
            
            role = self.queue_system.login(username, password)
            if role == 'admin':
                self.manager.current = 'admin_dashboard'
            elif role == 'user':
                self.manager.current = 'user_dashboard'
            else:
                self.show_message("Invalid credentials")
        except Exception as e:
            self.show_message(f"Login error: {str(e)}")
            print(f"Login error: {e}")
    
    def go_to_register(self, *args):
        self.manager.current = 'register'
    
    def show_message(self, text):
        try:
            snackbar = Snackbar()
            snackbar.text = text
            snackbar.open()
        except Exception as e:
            print(f"Snackbar error: {e}")
            print(f"Message: {text}")