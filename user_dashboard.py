from kivymd.uix.screen import MDScreen
from kivymd.uix.boxlayout import MDBoxLayout
from kivymd.uix.card import MDCard
from kivymd.uix.label import MDLabel
from kivymd.uix.button import MDRaisedButton, MDFlatButton
from kivymd.uix.scrollview import MDScrollView
from kivymd.uix.toolbar import MDTopAppBar
from kivymd.uix.snackbar import Snackbar
from kivy.clock import Clock
from kivy.metrics import dp


class UserDashboardScreen(MDScreen):
    def __init__(self, **kwargs):
        super().__init__(**kwargs)
        self.queue_system = None
        self.build_ui()
        self.update_event = None
    
    def set_queue_system(self, queue_system):
        self.queue_system = queue_system
    
    def build_ui(self):
        layout = MDBoxLayout(orientation='vertical')
        
        # Top bar
        toolbar = MDTopAppBar(
            title="Queue Dashboard",
            right_action_items=[["logout", lambda x: self.logout()]]
        )
        
        # Main content
        scroll = MDScrollView()
        content = MDBoxLayout(orientation='vertical', spacing=dp(20), padding=dp(20))
        content.bind(minimum_height=content.setter('height'))
        
        # Current status card
        self.status_card = MDCard(
            size_hint_y=None,
            height=dp(120),
            padding=dp(15),
            elevation=2
        )
        self.status_layout = MDBoxLayout(orientation='vertical')
        self.status_card.add_widget(self.status_layout)
        
        # Available queues
        queues_label = MDLabel(
            text="Available Queues:",
            theme_text_color="Primary",
            size_hint_y=None,
            height=dp(40)
        )
        
        # Queue buttons
        for queue_name in ['General Service', 'Priority Service', 'Technical Support']:
            btn = MDRaisedButton(
                text=f"Join {queue_name}",
                size_hint_y=None,
                height=dp(40),
                on_release=lambda x, qn=queue_name: self.join_queue(qn)
            )
            content.add_widget(btn)
        
        # Leave queue button
        self.leave_btn = MDFlatButton(
            text="Leave Current Queue",
            size_hint_y=None,
            height=dp(40),
            on_release=self.leave_queue
        )
        
        content.add_widget(self.status_card)
        content.add_widget(queues_label)
        content.add_widget(self.leave_btn)
        
        scroll.add_widget(content)
        layout.add_widget(toolbar)
        layout.add_widget(scroll)
        
        self.add_widget(layout)
    
    def on_enter(self):
        self.update_status()
        self.update_event = Clock.schedule_interval(self.update_status, 5)  # Update every 5 seconds
    
    def on_leave(self):
        if self.update_event:
            self.update_event.cancel()
    
    def update_status(self, *args):
        if not self.queue_system:
            return
            
        self.status_layout.clear_widgets()
        
        position_info = self.queue_system.get_user_position()
        if position_info:
            status_text = f"Queue: {position_info['queue_name']}\n"
            status_text += f"Position: {position_info['position']} of {position_info['total_in_queue']}\n"
            status_text += f"Estimated wait: {position_info['estimated_wait_minutes']} minutes"
            
            status_label = MDLabel(
                text=status_text,
                theme_text_color="Primary",
                halign="left"
            )
            self.status_layout.add_widget(status_label)
            self.leave_btn.disabled = False
        else:
            status_label = MDLabel(
                text="You are not currently in any queue",
                theme_text_color="Hint",
                halign="center"
            )
            self.status_layout.add_widget(status_label)
            self.leave_btn.disabled = True
    
    def join_queue(self, queue_name):
        if not self.queue_system:
            return
            
        if self.queue_system.join_queue(queue_name):
            self.show_message(f"Successfully joined {queue_name}")
            self.update_status()
        else:
            self.show_message("Already in a queue or unable to join")
    
    def leave_queue(self, *args):
        if not self.queue_system:
            return
            
        if self.queue_system.leave_queue():
            self.show_message("Left queue successfully")
            self.update_status()
    
    def logout(self):
        if self.queue_system:
            self.queue_system.current_user = None
            self.queue_system.user_role = None
        self.manager.current = 'login'
    
    def show_message(self, text):
        try:
            snackbar = Snackbar()
            snackbar.text = text
            snackbar.open()
        except Exception as e:
            print(f"Snackbar error: {e}")
            print(f"Message: {text}")