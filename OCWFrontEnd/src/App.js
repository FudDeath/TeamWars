import React, { useState, useEffect } from 'react';
import { ThemeProvider, createTheme } from '@mui/material/styles';
import {
  Container,
  Typography,
  Box,
  Grid,
  Card,
  CardContent,
  CardActions,
  Button,
  LinearProgress,
  AppBar,
  Toolbar,
} from '@mui/material';

const theme = createTheme({
  palette: {
    mode: 'dark',
    primary: {
      main: '#4caf50',
    },
    secondary: {
      main: '#f44336',
    },
    background: {
      default: '#121212',
      paper: '#1e1e1e',
    },
  },
  typography: {
    fontFamily: 'Arial, sans-serif',
  },
});

const App = () => {
  const [character, setCharacter] = useState(null);
  const [dungeonLevel, setDungeonLevel] = useState(null);
  const [dungeonResult, setDungeonResult] = useState(null);
  const [remainingTime, setRemainingTime] = useState(null);

  useEffect(() => {
    let timer;
    if (remainingTime > 0) {
      timer = setTimeout(() => {
        setRemainingTime(remainingTime - 1);
      }, 1000);
    }
    return () => clearTimeout(timer);
  }, [remainingTime]);

  const createCharacter = async () => {
    const newCharacter = {
      level: 1,
      exp: 0,
      max_hp: 100,
      current_hp: 100,
      is_injured: false,
    };
    setCharacter(newCharacter);
  };

  const enterDungeon = async (level) => {
    setDungeonLevel(level);
    const result = {
      success: Math.random() < 0.6,
      exp_gained: 100,
      ocw_reward: 50,
    };
    setDungeonResult(result);
    setRemainingTime(21600); // 6 hours in seconds

    if (result.success) {
      setCharacter((prevCharacter) => ({
        ...prevCharacter,
        exp: prevCharacter.exp + result.exp_gained,
        current_hp: prevCharacter.max_hp,
      }));
    } else {
      setCharacter((prevCharacter) => ({
        ...prevCharacter,
        current_hp: Math.max(0, prevCharacter.current_hp - 30),
        is_injured: true,
      }));
    }
  };

  const healCharacter = async () => {
    setCharacter((prevCharacter) => ({
      ...prevCharacter,
      current_hp: prevCharacter.max_hp,
      is_injured: false,
    }));
  };

  const formatTime = (time) => {
    const hours = Math.floor(time / 3600);
    const minutes = Math.floor((time % 3600) / 60);
    const seconds = time % 60;
    return `${hours.toString().padStart(2, '0')}:${minutes
      .toString()
      .padStart(2, '0')}:${seconds.toString().padStart(2, '0')}`;
  };

  return (
    <ThemeProvider theme={theme}>
      <AppBar position="static">
        <Toolbar>
          <Typography variant="h6" component="div" sx={{ flexGrow: 1 }}>
            On-Chain Clan Wars
          </Typography>
        </Toolbar>
      </AppBar>
      <Container maxWidth="md">
        <Box mt={4}>
          {!character ? (
            <Box textAlign="center">
              <Typography variant="h4" gutterBottom>
                Welcome to On-Chain Clan Wars!
              </Typography>
              <Typography variant="body1" paragraph>
                Embark on an epic adventure, battle in dungeons, and rise to the top of the clan rankings.
              </Typography>
              <Button variant="contained" size="large" onClick={createCharacter}>
                Create Character
              </Button>
            </Box>
          ) : (
            <Grid container spacing={4}>
              <Grid item xs={12} md={6}>
                <Card>
                  <CardContent>
                    <Typography variant="h5" gutterBottom>
                      Character Stats
                    </Typography>
                    <Typography variant="body1">Level: {character.level}</Typography>
                    <Typography variant="body1">Experience: {character.exp}</Typography>
                    <Typography variant="body1">
                      Health: {character.current_hp}/{character.max_hp}
                    </Typography>
                  </CardContent>
                  <CardActions>
                    <Button variant="contained" onClick={healCharacter} disabled={!character.is_injured}>
                      Heal Character
                    </Button>
                  </CardActions>
                </Card>
              </Grid>
              <Grid item xs={12} md={6}>
                <Card>
                  <CardContent>
                    <Typography variant="h5" gutterBottom>
                      Enter Dungeon
                    </Typography>
                    <Grid container spacing={2}>
                      {[1, 2, 3, 4, 5].map((level) => (
                        <Grid item key={level} xs={12}>
                          <Button
                            variant="contained"
                            color="primary"
                            fullWidth
                            onClick={() => enterDungeon(level)}
                          >
                            Level {level} Dungeon
                          </Button>
                        </Grid>
                      ))}
                    </Grid>
                  </CardContent>
                </Card>
              </Grid>
              {dungeonResult && (
                <Grid item xs={12}>
                  <Card>
                    <CardContent>
                      <Typography variant="h5" gutterBottom>
                        Dungeon Result
                      </Typography>
                      <Typography variant="body1">
                        {dungeonResult.success ? 'Success!' : 'Failure!'}
                      </Typography>
                      <Typography variant="body1">Experience Gained: {dungeonResult.exp_gained}</Typography>
                      <Typography variant="body1">OCW Reward: {dungeonResult.ocw_reward}</Typography>
                      {remainingTime > 0 && (
                        <Box mt={2}>
                          <Typography variant="body1">Time Remaining: {formatTime(remainingTime)}</Typography>
                          <LinearProgress variant="determinate" value={(remainingTime / 21600) * 100} />
                        </Box>
                      )}
                    </CardContent>
                  </Card>
                </Grid>
              )}
            </Grid>
          )}
        </Box>
      </Container>
    </ThemeProvider>
  );
};

export default App;
