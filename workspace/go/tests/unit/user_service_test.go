/**
 * User Service Unit Tests
 */

package services

import (
	"errors"
	"testing"

	"github.com/nexusforge/api/internal/models"
	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/mock"
)

// Mock Repository
type MockUserRepository struct {
	mock.Mock
}

func (m *MockUserRepository) Create(user *models.User) error {
	args := m.Called(user)
	return args.Error(0)
}

func (m *MockUserRepository) FindByID(id uint) (*models.User, error) {
	args := m.Called(id)
	if args.Get(0) == nil {
		return nil, args.Error(1)
	}
	return args.Get(0).(*models.User), args.Error(1)
}

func (m *MockUserRepository) FindByEmail(email string) (*models.User, error) {
	args := m.Called(email)
	if args.Get(0) == nil {
		return nil, args.Error(1)
	}
	return args.Get(0).(*models.User), args.Error(1)
}

func (m *MockUserRepository) FindByUsername(username string) (*models.User, error) {
	args := m.Called(username)
	if args.Get(0) == nil {
		return nil, args.Error(1)
	}
	return args.Get(0).(*models.User), args.Error(1)
}

func (m *MockUserRepository) List(page, limit int) ([]*models.User, int64, error) {
	args := m.Called(page, limit)
	return args.Get(0).([]*models.User), args.Get(1).(int64), args.Error(2)
}

func (m *MockUserRepository) Update(user *models.User) error {
	args := m.Called(user)
	return args.Error(0)
}

func (m *MockUserRepository) Delete(id uint) error {
	args := m.Called(id)
	return args.Error(0)
}

func (m *MockUserRepository) UpdateLastLogin(id uint) error {
	args := m.Called(id)
	return args.Error(0)
}

// Mock Cache Manager
type MockCacheManager struct {
	mock.Mock
}

func (m *MockCacheManager) Get(key string, dest interface{}) error {
	args := m.Called(key, dest)
	return args.Error(0)
}

func (m *MockCacheManager) Set(key string, value interface{}, ttl any) error {
	args := m.Called(key, value, ttl)
	return args.Error(0)
}

func (m *MockCacheManager) Delete(key string) error {
	args := m.Called(key)
	return args.Error(0)
}

func (m *MockCacheManager) Exists(key string) (bool, error) {
	args := m.Called(key)
	return args.Bool(0), args.Error(1)
}

func (m *MockCacheManager) DeletePattern(pattern string) error {
	args := m.Called(pattern)
	return args.Error(0)
}

// Mock Logger
type MockLogger struct{}

func (m *MockLogger) Debug(msg string, fields ...interface{}) {}
func (m *MockLogger) Info(msg string, fields ...interface{})  {}
func (m *MockLogger) Warn(msg string, fields ...interface{})  {}
func (m *MockLogger) Error(msg string, fields ...interface{}) {}
func (m *MockLogger) Fatal(msg string, fields ...interface{}) {}

func TestCreateUser_Success(t *testing.T) {
	mockRepo := new(MockUserRepository)
	mockCache := new(MockCacheManager)
	mockLog := &MockLogger{}

	service := NewUserService(mockRepo, mockCache, mockLog)

	req := &models.CreateUserRequest{
		Email:    "test@example.com",
		Username: "testuser",
		Password: "password123",
	}

	mockRepo.On("FindByEmail", req.Email).Return(nil, nil)
	mockRepo.On("FindByUsername", req.Username).Return(nil, nil)
	mockRepo.On("Create", mock.AnythingOfType("*models.User")).Return(nil)

	user, err := service.CreateUser(req)

	assert.NoError(t, err)
	assert.NotNil(t, user)
	assert.Equal(t, req.Email, user.Email)
	assert.Equal(t, req.Username, user.Username)
	mockRepo.AssertExpectations(t)
}

func TestCreateUser_EmailExists(t *testing.T) {
	mockRepo := new(MockUserRepository)
	mockCache := new(MockCacheManager)
	mockLog := &MockLogger{}

	service := NewUserService(mockRepo, mockCache, mockLog)

	req := &models.CreateUserRequest{
		Email:    "existing@example.com",
		Username: "testuser",
		Password: "password123",
	}

	existingUser := &models.User{ID: 1, Email: req.Email}
	mockRepo.On("FindByEmail", req.Email).Return(existingUser, nil)

	user, err := service.CreateUser(req)

	assert.Error(t, err)
	assert.Nil(t, user)
	assert.Equal(t, "email already registered", err.Error())
	mockRepo.AssertExpectations(t)
}

func TestGetUserByID_FromCache(t *testing.T) {
	mockRepo := new(MockUserRepository)
	mockCache := new(MockCacheManager)
	mockLog := &MockLogger{}

	service := NewUserService(mockRepo, mockCache, mockLog)

	userID := uint(1)
	mockCache.On("Get", "user:1", mock.AnythingOfType("*models.UserResponse")).Return(nil)

	user, err := service.GetUserByID(userID)

	assert.NoError(t, err)
	assert.NotNil(t, user)
	mockCache.AssertExpectations(t)
}

func TestDeleteUser_Success(t *testing.T) {
	mockRepo := new(MockUserRepository)
	mockCache := new(MockCacheManager)
	mockLog := &MockLogger{}

	service := NewUserService(mockRepo, mockCache, mockLog)

	userID := uint(1)
	mockRepo.On("Delete", userID).Return(nil)
	mockCache.On("Delete", "user:1").Return(nil)

	err := service.DeleteUser(userID)

	assert.NoError(t, err)
	mockRepo.AssertExpectations(t)
	mockCache.AssertExpectations(t)
}
