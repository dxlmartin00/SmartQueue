import json
from datetime import datetime, timedelta
from typing import Dict, List, Optional


class QueueSystem:
    """Backend logic for the queue system"""
    
    def __init__(self):
        self.queues: Dict[str, List] = {
            'General Service': [],
            'Priority Service': [],
            'Technical Support': []
        }
        self.users: Dict[str, Dict] = {}
        self.admins = {'admin': 'admin123'}
        self.current_user = None
        self.user_role = None  # 'user' or 'admin'
        self.queue_stats = {
            'total_served': 0,
            'avg_wait_time': 0,
            'peak_hour': '10:00 AM'
        }
        
    def register_user(self, username: str, password: str, full_name: str, phone: str) -> bool:
        try:
            if not all([username, password, full_name, phone]):
                return False
                
            if username in self.users:
                return False
                
            self.users[username] = {
                'password': password,
                'full_name': full_name,
                'phone': phone,
                'queue_history': []
            }
            print(f"User registered successfully: {username}")
            return True
        except Exception as e:
            print(f"Registration error in queue_system: {e}")
            return False
    
    def login(self, username: str, password: str) -> Optional[str]:
        # Check admin credentials
        if username in self.admins and self.admins[username] == password:
            self.current_user = username
            self.user_role = 'admin'
            return 'admin'
        
        # Check user credentials
        if username in self.users and self.users[username]['password'] == password:
            self.current_user = username
            self.user_role = 'user'
            return 'user'
        
        return None
    
    def join_queue(self, queue_name: str, priority: bool = False) -> bool:
        if not self.current_user or self.user_role != 'user':
            return False
        
        # Check if user is already in any queue
        for q_name, queue in self.queues.items():
            if any(item['username'] == self.current_user for item in queue):
                return False
        
        queue_item = {
            'username': self.current_user,
            'full_name': self.users[self.current_user]['full_name'],
            'join_time': datetime.now(),
            'priority': priority,
            'status': 'waiting'
        }
        
        if priority:
            # Insert priority customers at the beginning (after other priority customers)
            priority_count = sum(1 for item in self.queues[queue_name] if item.get('priority', False))
            self.queues[queue_name].insert(priority_count, queue_item)
        else:
            self.queues[queue_name].append(queue_item)
        
        return True
    
    def leave_queue(self, queue_name: str = None) -> bool:
        if not self.current_user:
            return False
        
        if queue_name:
            queues_to_check = [queue_name]
        else:
            queues_to_check = self.queues.keys()
        
        for q_name in queues_to_check:
            self.queues[q_name] = [item for item in self.queues[q_name] 
                                 if item['username'] != self.current_user]
        return True
    
    def get_user_position(self) -> Optional[Dict]:
        if not self.current_user or self.user_role != 'user':
            return None
        
        for q_name, queue in self.queues.items():
            for i, item in enumerate(queue):
                if item['username'] == self.current_user:
                    wait_time = datetime.now() - item['join_time']
                    estimated_wait = max(0, (i * 5) - int(wait_time.total_seconds() // 60))
                    return {
                        'queue_name': q_name,
                        'position': i + 1,
                        'total_in_queue': len(queue),
                        'estimated_wait_minutes': estimated_wait,
                        'status': item['status']
                    }
        return None
    
    def call_next_customer(self, queue_name: str) -> Optional[Dict]:
        if not self.current_user or self.user_role != 'admin':
            return None
        
        if queue_name not in self.queues or not self.queues[queue_name]:
            return None
        
        customer = self.queues[queue_name].pop(0)
        customer['served_time'] = datetime.now()
        self.queue_stats['total_served'] += 1
        
        # Add to user's history
        if customer['username'] in self.users:
            self.users[customer['username']]['queue_history'].append({
                'queue_name': queue_name,
                'join_time': customer['join_time'],
                'served_time': customer['served_time'],
                'wait_time_minutes': int((customer['served_time'] - customer['join_time']).total_seconds() // 60)
            })
        
        return customer
    
    def get_queue_overview(self) -> Dict:
        overview = {}
        for q_name, queue in self.queues.items():
            overview[q_name] = {
                'count': len(queue),
                'customers': [{'name': item['full_name'], 
                             'wait_time': int((datetime.now() - item['join_time']).total_seconds() // 60),
                             'priority': item.get('priority', False)} for item in queue]
            }
        return overview